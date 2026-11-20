import AppKit
import ConfigKit
import CityKit

/// Read-only Dock tracking. Predictive motion is opt-in until measured on a Mac.
public final class SystemDockCityTracker {
    public var onStatus: ((String) -> Void)?
    public var onApplicationsChanged: (() -> Void)?
    public private(set) var applications: [String: String] = [:]
    private let panel = TrackedCityPanel()
    private let diagnostics = DockDiagnostics()
    private let activity = AppActivityMonitor()
    private let worker = DispatchQueue(label: "com.metaparodica.DockCity.geometry", qos: .userInitiated)
    private let predictive = CommandLine.arguments.contains("--predictive-dock")
    private var timer: Timer?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var settings = CitySettings()
    private var latest: SystemDockSnapshot?
    private var busy = false, started = false, sleeping = false, lastReduced = false
    private var generation = 0
    private var nextPoll = 0.0, lastRead = -Double.infinity, predictionUntil = 0.0
    private var lastStatus = ""
    private var bundleIDs: [String: String] = [:]
    private var grace = DockSampleGrace()
    private var launches = CityLaunchEvents()
    private struct Cache {
        let layout: TrackedCityLayout; let tiles: [CityTile]; let signature: String
        let pid: pid_t; let time: Double
    }
    private var cache: Cache?
    private var hoverLayout: TrackedCityLayout?
    private var itemIDs: [Int: String] = [:]
    private var wasAtEdge = false
    private var wasInsideDock = false, hidingUntil = 0.0
    public init() {}
    private var now: Double { ProcessInfo.processInfo.systemUptime }
    private var reduced: Bool {
        settings.lowPower || settings.reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    public func start(settings: CitySettings) {
        guard !started else { update(settings: settings); return }
        started = true; self.settings = settings
        panel.onVisibilityChanged = { [weak self] in self?.diagnostics.visibility($0, frame: $1) }
        panel.onRenderedVisibilityChanged = { [weak self] in self?.diagnostics.rendered($0, frame: $1) }
        diagnostics.event("tracking_mode", fields: ["predictive": predictive, "city_level": panel.level.rawValue])
        activity.onChange = { [weak self] in self?.refresh() }
        activity.onLaunch = { [weak self] id, path in
            guard let self, self.settings.enabled else { return }
            self.launches.launched(bundleID: id, path: path, now: self.now)
            self.refresh()
        }
        activity.start()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observe(nc, name) { [weak self] in self?.sleeping = true; self?.invalidate() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observe(nc, name) { [weak self] in self?.sleeping = false; self?.invalidate() }
        }
        observe(nc, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in self?.invalidate() }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.invalidate() }
        scheduleTimer(); tick()
        if !settings.enabled { status("City paused") }
    }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping () -> Void) {
        tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }))
    }
    private func scheduleTimer() {
        timer?.invalidate(); timer = nil
        guard started, settings.enabled else { return }
        lastReduced = reduced
        let interval = reduced ? 0.1 : 1 / max(predictive ? 60 : 10, settings.quality.fps)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    public func update(settings: CitySettings) {
        self.settings = settings
        if started { scheduleTimer() }
        cache = nil; predictionUntil = 0
        if !settings.enabled { invalidate(); status("City paused") }
        else { nextPoll = 0; refresh() }
    }
    public func stop() {
        started = false; invalidate(); timer?.invalidate(); timer = nil; activity.stop()
        tokens.forEach { $0.0.removeObserver($0.1) }; tokens.removeAll()
    }
    private func invalidate() {
        generation += 1; latest = nil; cache = nil; hoverLayout = nil; itemIDs = [:]
        launches = CityLaunchEvents()
        predictionUntil = 0; hidingUntil = 0; grace.reset(); wasAtEdge = false; wasInsideDock = false; nextPoll = 0; panel.orderOut(nil)
    }
    private func signature(_ snapshot: SystemDockSnapshot) -> String {
        "\(snapshot.pid):\(snapshot.orientation ?? ""):\(snapshot.tileSize ?? 0):" + snapshot.items.map {
            "\($0.role):\($0.subrole):\($0.applicationURL?.absoluteString ?? String($0.index))"
        }.joined(separator: "|")
    }
    private func trackPointer() {
        let point = NSEvent.mouseLocation
        diagnostics.pointer(point, orientation: latest?.orientation)
        if let layout = hoverLayout {
            let index = DockHover.itemIndex(at: point, items: layout.items, frames: layout.itemFrames)
            panel.hover(tileID: index.flatMap { itemIDs[$0] })
        }
        guard predictive, latest?.autohide == true, let cache, now - cache.time < 300,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(cache.layout.frame) }),
              NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier == cache.pid else { return }
        let f = screen.frame
        let atEdge: Bool
        switch cache.layout.orientation {
        case .bottom: atEdge = point.y <= f.minY + 2
        case .left: atEdge = point.x <= f.minX + 2
        case .right: atEdge = point.x >= f.maxX - 2
        }
        let entered = atEdge && f.insetBy(dx: -1, dy: -1).contains(point)
        let dockBounds = cache.layout.itemFrames.reduce(CGRect.null) { $0.union($1) }
        let inside = entered || dockBounds.insetBy(dx: -4, dy: -4).contains(point)
        defer { wasAtEdge = entered; wasInsideDock = inside }
        if inside { hidingUntil = 0 }
        if entered && !wasAtEdge {
            let timing = DockMotionPreferences()
            predictionUntil = now + timing.delay + timing.duration + 0.25
            panel.apply(layout: cache.layout, tiles: cache.tiles, settings: settings, duration: timing.duration, delay: timing.delay)
            nextPoll = 0
            diagnostics.event("predictive_reveal", fields: ["delay_ms": timing.delay * 1000,
                "duration_ms": timing.duration * 1000, "uses_estimated_defaults": timing.usesEstimate])
        }
        if wasInsideDock && !inside {
            let duration = DockMotionPreferences().duration
            predictionUntil = 0; hidingUntil = now + duration + 0.15; panel.hide(duration: duration)
            diagnostics.event("predictive_hide", fields: ["duration_ms": duration * 1000])
        }
    }
    private func tick() {
        guard started, !sleeping, settings.enabled else { return }
        if reduced != lastReduced { scheduleTimer() }
        guard DockAccessibility.isTrusted else { invalidate(); status("Accessibility permission required"); return }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            invalidate(); status("Waiting for macOS Dock"); return
        }
        if let cache, cache.pid != dock.processIdentifier { invalidate() }
        trackPointer(); panel.tick()
        if now - lastRead > 0.8 && now > predictionUntil { panel.orderOut(nil) }
        guard now >= nextPoll, !busy else { return }
        nextPoll = now + (reduced ? 0.4 : predictive && panel.isVisible ? 1 / 60 : 0.1)
        busy = true
        let pid = dock.processIdentifier, version = generation, requested = now
        diagnostics.event("ax_read_start")
        worker.async { [weak self] in
            let result = Result { try SystemDockAXReader.read(pid: pid) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }; self.busy = false
                guard self.started, !self.sleeping, self.settings.enabled, version == self.generation else { return }
                guard DockAccessibility.isTrusted,
                      NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier == pid else {
                    self.invalidate(); return
                }
                switch result {
                case .success(let snapshot):
                    self.diagnostics.snapshot(snapshot, readMS: (self.now - requested) * 1000)
                    guard self.now - requested < 0.8 else { self.badSample("Stale Dock response"); return }
                    if !snapshot.incomplete, !snapshot.items.isEmpty,
                       let cache = self.cache, cache.signature != self.signature(snapshot) {
                        self.cache = nil; self.predictionUntil = 0
                    }
                    if snapshot.autohide != true {
                        self.predictionUntil = 0; self.hidingUntil = 0
                        self.wasAtEdge = false; self.wasInsideDock = false
                    }
                    self.lastRead = self.now; self.latest = snapshot; self.refresh()
                case .failure(let error):
                    self.diagnostics.event("ax_read_failure", fields: ["reason": String(describing: error)])
                    self.badSample(String(describing: error))
                }
            }
        }
    }
    private func badSample(_ message: String, hidden: Bool = false) {
        diagnostics.event("geometry_unavailable", fields: ["confirmed_hidden": hidden,
            "held": grace.canHold(now: now), "prediction_active": now < predictionUntil])
        if now < predictionUntil { return }
        if hidden || !grace.canHold(now: now) {
            if predictive && latest?.autohide == true { panel.hide(duration: DockMotionPreferences().duration) }
            else { panel.orderOut(nil) }
            panel.hover(tileID: nil)
        }
        status(message)
    }
    private func refresh() {
        guard started, !sleeping, settings.enabled, DockAccessibility.isTrusted,
              now - lastRead < 0.8, let snapshot = latest, !snapshot.incomplete,
              let raw = snapshot.orientation, let orientation = SystemDockOrientation(rawValue: raw) else {
            badSample("Waiting for fresh Dock geometry"); return
        }
        let screens = NSScreen.screens.map(\.frame), primaryY = screens.first?.maxY ?? 0
        let visible = snapshot.dockWindowFrame.map {
            TrackedCityLayout.dockWindowIsVisible($0, primaryMaxY: primaryY, screens: screens, orientation: orientation)
        } ?? false
        guard visible, let layout = TrackedCityLayout.make(items: snapshot.items, primaryMaxY: primaryY,
            screens: screens, orientation: orientation, height: CGFloat(settings.size.height)) else {
            badSample("Waiting for visible Dock geometry", hidden: snapshot.dockWindowFrame != nil && !visible); return
        }
        let running = activity.snapshot()
        let states = running.map { CityAppState(bundleID: $0.bundleID, path: $0.bundlePath, active: $0.isActive) }
        var apps: [String: String] = [:], occurrences: [String: Int] = [:], ids: [Int: String] = [:]
        let tiles = zip(layout.items, layout.itemFrames).compactMap { item, rect -> CityTile? in
            guard item.kind == .application else { return nil }
            let path = item.applicationURL?.standardizedFileURL.path
            let bundleID: String?
            if let path {
                if let known = running.first(where: { $0.bundlePath == path })?.bundleID { bundleIDs[path] = known }
                else if bundleIDs[path] == nil { bundleIDs[path] = Bundle(path: path)?.bundleIdentifier }
                bundleID = bundleIDs[path]
            } else { bundleID = nil }
            if let bundleID { apps[bundleID] = item.title }
            let identity = path ?? "unresolved-AX-item-\(item.index)"
            let occurrence = occurrences[identity, default: 0]; occurrences[identity] = occurrence + 1
            let id = "\(identity):\(occurrence)"; ids[item.index] = id
            let state = path.map { CityAppState.activity(bundleID: bundleID, path: $0, running: states) } ?? .inactive
            return CityTile(id: id, bundleID: bundleID, center: layout.center(of: rect),
                width: Double(orientation == .bottom ? rect.width : rect.height), activity: state)
        }
        guard !tiles.isEmpty else { badSample("No readable Dock applications"); return }
        grace.accept(now: now); hoverLayout = layout; itemIDs = ids
        cache = Cache(layout: layout, tiles: tiles, signature: signature(snapshot), pid: snapshot.pid, time: now)
        if applications != apps { applications = apps; onApplicationsChanged?() }
        panel.apply(layout: layout, tiles: tiles, settings: settings, reveal: now >= hidingUntil)
        panel.launched(tileIDs: launches.consume(tiles: tiles, now: now))
        status("Tracking macOS Dock · \(tiles.count) apps")
    }
    private func status(_ value: String) {
        guard lastStatus != value else { return }; lastStatus = value; onStatus?(value)
    }
}
