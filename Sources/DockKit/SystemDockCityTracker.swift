import AppKit
import ConfigKit
import CityKit

/// Owns a single click-through city and reads the real Dock on a serial worker.
/// Never launches apps, changes Dock preferences, or creates replacement icons.
public final class SystemDockCityTracker {
    public var onStatus: ((String) -> Void)?
    public var onApplicationsChanged: (() -> Void)?
    public var onDockSnapshot: ((SystemDockSnapshot?) -> Void)?
    public var tracksDockGeometry = false {
        didSet {
            guard started else { return }
            scheduleTimer(); nextPoll = .distantPast
            if !tracksDockGeometry && !settings.enabled { invalidate() }
        }
    }
    public private(set) var applications: [String: String] = [:]
    private let panel = TrackedCityPanel()
    private let activity = AppActivityMonitor()
    private let worker = DispatchQueue(label: "com.metaparodica.DockCity.geometry", qos: .userInitiated)
    private var timer: Timer?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var settings = CitySettings()
    private var latest: SystemDockSnapshot?
    private var busy = false
    private var started = false
    private var sleeping = false
    private var generation = 0
    private var nextPoll = Date.distantPast
    private var lastRead = Date.distantPast
    private var lastStatus = ""
    private var lastReduced = false
    private var bundleIDs: [String: String] = [:]

    public init() {}

    public func start(settings: CitySettings) {
        guard !started else { update(settings: settings); return }
        started = true; self.settings = settings
        activity.onChange = { [weak self] in self?.refresh() }
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
        scheduleTimer()
        if !settings.enabled { status("City paused") }
        tick()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        guard started, settings.enabled || tracksDockGeometry else { timer = nil; return }
        let reduced = settings.lowPower || settings.reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let interval = reduced ? 0.1 : 1 / max(10, settings.quality.fps)
        lastReduced = reduced
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common); timer = t
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping () -> Void) {
        tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }))
    }

    public func update(settings: CitySettings) {
        self.settings = settings
        if started { scheduleTimer() }
        if !settings.enabled { invalidate(); status("City paused") }
        else { nextPoll = .distantPast; refresh() }
    }

    public func stop() {
        started = false; generation += 1
        timer?.invalidate(); timer = nil; activity.stop()
        tokens.forEach { $0.0.removeObserver($0.1) }; tokens.removeAll()
        latest = nil; panel.orderOut(nil); onDockSnapshot?(nil)
    }

    private func invalidate() {
        generation += 1; latest = nil; panel.orderOut(nil); nextPoll = .distantPast; onDockSnapshot?(nil)
    }

    private func tick() {
        guard started, !sleeping, settings.enabled || tracksDockGeometry else { return }
        let reduced = settings.lowPower || settings.reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduced != lastReduced { scheduleTimer() }
        if Date().timeIntervalSince(lastRead) > 0.8 { panel.orderOut(nil); onDockSnapshot?(nil) }
        panel.tick()
        guard Date() >= nextPoll else { return }
        nextPoll = Date().addingTimeInterval(settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.4 : 0.1)
        guard DockAccessibility.isTrusted else {
            invalidate(); status("Accessibility permission required"); return
        }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            invalidate(); status("Waiting for macOS Dock"); return
        }
        guard !busy else { return }
        busy = true
        let pid = dock.processIdentifier, version = generation, requested = Date()
        worker.async { [weak self] in
            let result = Result { try SystemDockAXReader.read(pid: pid) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.busy = false
                guard self.started, !self.sleeping, self.settings.enabled || self.tracksDockGeometry, version == self.generation else { return }
                guard DockAccessibility.isTrusted,
                      NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier == pid,
                      Date().timeIntervalSince(requested) < 0.8 else {
                    self.latest = nil; self.panel.orderOut(nil); self.onDockSnapshot?(nil); self.status("Waiting for fresh Dock geometry"); return
                }
                switch result {
                case .success(let snapshot):
                    self.lastRead = Date(); self.latest = snapshot; self.refresh()
                case .failure(let error):
                    self.latest = nil; self.panel.orderOut(nil); self.onDockSnapshot?(nil); self.status(String(describing: error))
                }
            }
        }
    }

    private func refresh() {
        if let snapshot = latest, Date().timeIntervalSince(lastRead) < 0.8, DockAccessibility.isTrusted {
            onDockSnapshot?(snapshot)
        } else { onDockSnapshot?(nil) }
        guard settings.enabled else { panel.orderOut(nil); return }
        guard started, !sleeping, settings.enabled, DockAccessibility.isTrusted,
              Date().timeIntervalSince(lastRead) < 0.8,
              let snapshot = latest, !snapshot.incomplete,
              NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier == snapshot.pid,
              let raw = snapshot.orientation, let orientation = SystemDockOrientation(rawValue: raw),
              let window = snapshot.dockWindowFrame, SystemDockGeometry.valid(window),
              TrackedCityLayout.dockWindowIsVisible(window, primaryMaxY: NSScreen.screens.first?.frame.maxY ?? 0,
                screens: NSScreen.screens.map(\.frame), orientation: orientation),
              let layout = TrackedCityLayout.make(items: snapshot.items,
                primaryMaxY: NSScreen.screens.first?.frame.maxY ?? 0, screens: NSScreen.screens.map(\.frame),
                orientation: orientation, height: CGFloat(settings.size.height)) else {
            panel.orderOut(nil)
            if settings.enabled { status("Waiting for visible Dock geometry") }
            return
        }
        let running = activity.snapshot()
        let states = running.map { CityAppState(bundleID: $0.bundleID, path: $0.bundlePath, active: $0.isActive) }
        var apps: [String: String] = [:]
        var occurrences: [String: Int] = [:]
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
            let activity = path.map { CityAppState.activity(bundleID: bundleID, path: $0, running: states) } ?? .inactive
            return CityTile(id: "\(identity):\(occurrence)", bundleID: bundleID,
                            center: layout.center(of: rect), width: Double(orientation == .bottom ? rect.width : rect.height), activity: activity)
        }
        guard !tiles.isEmpty else { panel.orderOut(nil); status("No visible Dock applications"); return }
        if applications != apps { applications = apps; onApplicationsChanged?() }
        panel.apply(layout: layout, tiles: tiles, settings: settings)
        status("Tracking macOS Dock · \(tiles.count) apps")
    }

    private func status(_ value: String) {
        guard lastStatus != value else { return }
        lastStatus = value; onStatus?(value)
    }
}
