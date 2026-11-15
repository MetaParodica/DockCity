import AppKit
import QuartzCore
import ConfigKit
import CityKit
import SnowCore

final class SnowOverlayPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true; hidesOnDeactivate = false; isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 2)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class SnowOverlayView: NSView {
    let simulation: SnowSimulation
    override var isFlipped: Bool { true }
    init(size: CGSize) {
        simulation = SnowSimulation(width: Double(size.width), height: Double(size.height))
        super.init(frame: CGRect(origin: .zero, size: size))
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    private func mask(_ surfaces: ArraySlice<SnowSurface>) {
        // The panel is above apps. Remove foreground window interiors in software.
        // Clip sequentially so overlapping rectangles don't cancel via even-odd parity.
        for surface in surfaces {
            let f = surface.frame
            let path = NSBezierPath(rect: bounds)
            path.append(NSBezierPath(rect: CGRect(x: f.x, y: f.y, width: f.width, height: f.height)))
            path.windingRule = .evenOdd; path.addClip()
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using: .copy)
        let surfaces = simulation.surfaces
        for (index, surface) in surfaces.enumerated() {
            guard let pile = simulation.piles[surface.id], pile.heights.contains(where: { $0 > 0.05 }) else { continue }
            NSGraphicsContext.saveGraphicsState(); mask(surfaces.prefix(index))
            let path = NSBezierPath()
            path.move(to: CGPoint(x: surface.frame.x, y: surface.frame.y))
            for i in pile.heights.indices {
                path.line(to: CGPoint(x: surface.frame.x + (Double(i) + 0.5) * pile.cellWidth,
                                     y: surface.frame.y - pile.heights[i]))
            }
            path.line(to: CGPoint(x: surface.frame.right, y: surface.frame.y)); path.close()
            NSColor(calibratedRed: 0.91, green: 0.96, blue: 1, alpha: 0.96).setFill(); path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        NSGraphicsContext.saveGraphicsState(); mask(surfaces[...])
        NSColor.white.withAlphaComponent(0.85).setFill()
        let flakes = NSBezierPath()
        let trails = NSBezierPath()
        for p in simulation.particles {
            flakes.appendOval(in: CGRect(x: p.x - p.radius, y: p.y - p.radius, width: p.radius * 2, height: p.radius * 2))
            let speed = hypot(p.vx, p.vy)
            if p.debris, speed > 35 {
                let length = min(8, speed * 0.025)
                trails.move(to: CGPoint(x: p.x - p.vx / speed * length, y: p.y - p.vy / speed * length))
                trails.line(to: CGPoint(x: p.x, y: p.y))
            }
        }
        flakes.fill()
        NSColor.white.withAlphaComponent(0.2).setStroke(); trails.lineWidth = 1; trails.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// CG metadata only: no titles, pixel capture, event taps or Dock modifications.
enum SnowWindowMetadata {
    static func dockSurface(_ snapshot: SystemDockSnapshot, primaryMaxY: CGFloat, screens: [CGRect]) -> SnowSurface? {
        guard !snapshot.incomplete, let raw = snapshot.orientation,
              let orientation = SystemDockOrientation(rawValue: raw), let window = snapshot.dockWindowFrame,
              TrackedCityLayout.dockWindowIsVisible(window, primaryMaxY: primaryMaxY, screens: screens, orientation: orientation) else { return nil }
        let frames = snapshot.items.compactMap(\.axFrame).filter(SystemDockGeometry.valid)
        guard let first = frames.first,
              let screen = SystemDockGeometry.screenIndex(items: frames.map { SystemDockGeometry.cocoaFrame(axFrame: $0, primaryMaxY: primaryMaxY) }, screens: screens),
              frames.allSatisfy({ screens[screen].contains(SystemDockGeometry.cocoaFrame(axFrame: $0, primaryMaxY: primaryMaxY)) }) else { return nil }
        let rect = frames.dropFirst().reduce(first) { $0.union($1) }
        // Bottom Dock: long upper rim. Side Dock: the short physical top cap.
        return SnowSurface(id: UInt64.max, frame: SnowRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height), kind: .dock)
    }
    static func decode(_ rows: [[String: Any]], ownPID: pid_t) -> [SnowSurface] {
        let input = rows.prefix(512).compactMap { row -> SnowSurface? in
            guard let pid = row[kCGWindowOwnerPID as String] as? NSNumber, pid.int32Value != ownPID,
                  let layer = row[kCGWindowLayer as String] as? NSNumber, layer.intValue == 0,
                  let alpha = row[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue > 0.05,
                  let id = row[kCGWindowNumber as String] as? NSNumber,
                  id.doubleValue.isFinite, id.int64Value > 0, id.uint64Value <= UInt64(UInt32.max),
                  let raw = row[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  rect.width >= 60, rect.height >= 30 else { return nil }
            return SnowSurface(id: id.uint64Value, frame: SnowRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height))
        }
        return SnowScene.validated(input)
    }
}

public final class SnowOverlayController {
    public var onStatus: ((String) -> Void)?
    private struct Overlay { let panel: SnowOverlayPanel; let view: SnowOverlayView; let display: SnowRect }
    private var overlays: [Overlay] = []
    private var timer: Timer?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private let worker = DispatchQueue(label: "com.metaparodica.DockCity.snow.geometry", qos: .utility)
    private var settings = SnowSettings()
    private var started = false, sleeping = false, busy = false
    private var generation = 0
    private var lastTick = Date(), lastRead = Date.distantPast, nextRead = Date.distantPast
    private var dock: SystemDockSnapshot?
    private var dockTime = Date.distantPast
    private var lastStatus = ""
    private var lastReduced = false
    private var lastLowPower = false
    public init() {}

    public func start(settings: SnowSettings) {
        guard !started else { update(settings: settings); return }
        started = true; self.settings = settings
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observe(nc, name) { [weak self] in self?.sleeping = true; self?.reset() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observe(nc, name) { [weak self] in self?.sleeping = false; self?.reset() }
        }
        observe(nc, NSWorkspace.activeSpaceDidChangeNotification) { [weak self] in self?.reset() }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in self?.reset(rebuild: true) }
        rebuild(); schedule(); tick()
    }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ action: @escaping () -> Void) {
        tokens.append((center, center.addObserver(forName: name, object: nil, queue: .main) { _ in action() }))
    }
    public func update(settings: SnowSettings) {
        self.settings = settings
        for overlay in overlays { overlay.view.simulation.configure(effectiveSettings) }
        if !settings.enabled { reset(); status("Snow paused") }
        nextRead = .distantPast; schedule()
    }
    public func setDockSnapshot(_ snapshot: SystemDockSnapshot?) {
        let hadDock = dock != nil
        dock = snapshot; dockTime = snapshot == nil ? .distantPast : Date()
        if snapshot == nil && hadDock { nextRead = .distantPast }
    }
    public func clearSnow() {
        for o in overlays { o.view.simulation.clear(); o.view.needsDisplay = true }
        nextRead = .distantPast
    }
    public func stop() {
        started = false; generation += 1; timer?.invalidate(); timer = nil
        tokens.forEach { $0.0.removeObserver($0.1) }; tokens.removeAll()
        overlays.forEach { $0.panel.orderOut(nil) }; overlays.removeAll(); dock = nil
    }
    private var reduced: Bool {
        settings.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var effectiveSettings: SnowSettings {
        var s = settings; s.reduceMotion = reduced; return s
    }
    private func schedule() {
        timer?.invalidate(); timer = nil
        guard started, settings.enabled else { return }
        let interval = reduced ? 0.2 : settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 / 15.0 : 1 / 30.0
        lastLowPower = settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common); timer = t; lastTick = Date()
    }
    private func reset(rebuild: Bool = false) {
        generation += 1; lastRead = .distantPast; nextRead = .distantPast; dock = nil
        overlays.forEach { $0.panel.orderOut(nil); $0.view.simulation.clear() }
        if rebuild { self.rebuild() }
    }
    private func rebuild() {
        overlays.forEach { $0.panel.orderOut(nil) }; overlays.removeAll()
        let primaryY = NSScreen.screens.first?.frame.maxY ?? 0
        for screen in NSScreen.screens {
            let panel = SnowOverlayPanel(frame: screen.frame)
            let view = SnowOverlayView(size: screen.frame.size); panel.contentView = view
            view.simulation.configure(effectiveSettings)
            overlays.append(Overlay(panel: panel, view: view, display: SnowRect(x: screen.frame.minX,
                y: primaryY - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)))
        }
    }
    private func tick() {
        guard started, settings.enabled, !sleeping else { return }
        let now = Date(), dt = now.timeIntervalSince(lastTick); lastTick = now
        if lastReduced != reduced || lastLowPower != (settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled) {
            lastReduced = reduced; overlays.forEach { $0.view.simulation.configure(effectiveSettings) }; schedule()
        }
        if now.timeIntervalSince(lastRead) > 0.8 {
            overlays.forEach { $0.panel.orderOut(nil) }
        } else {
            for o in overlays where o.panel.isVisible { o.view.simulation.step(seconds: dt); o.view.needsDisplay = true }
        }
        guard !busy, now >= nextRead else { return }
        busy = true; nextRead = now.addingTimeInterval(lastLowPower ? 0.2 : 0.1)
        let version = generation, requested = now, pid = ProcessInfo.processInfo.processIdentifier
        worker.async { [weak self] in
            let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
            let surfaces = rows.map { SnowWindowMetadata.decode($0, ownPID: pid) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }; self.busy = false
                guard self.started, self.settings.enabled, !self.sleeping, self.generation == version else { return }
                guard let surfaces, Date().timeIntervalSince(requested) < 0.8 else {
                    self.overlays.forEach { $0.panel.orderOut(nil) }; self.status("Waiting for window geometry"); return
                }
                let elapsed = Date().timeIntervalSince(self.lastRead); self.lastRead = Date()
                self.apply(surfaces, elapsed: elapsed)
            }
        }
    }
    private func apply(_ windows: [SnowSurface], elapsed: Double) {
        var surfaces = windows
        if settings.accumulateOnDock, Date().timeIntervalSince(dockTime) < 0.8,
           DockAccessibility.isTrusted, let dock,
           let surface = SnowWindowMetadata.dockSurface(dock, primaryMaxY: NSScreen.screens.first?.frame.maxY ?? 0,
               screens: NSScreen.screens.map(\.frame)) {
            surfaces.insert(surface, at: 0)
        }
        for o in overlays {
            let local = SnowScene.local(surfaces, display: o.display)
            if SnowScene.fullscreen(in: local, width: o.display.width, height: o.display.height) {
                o.panel.orderOut(nil); o.view.simulation.clear(); continue
            }
            o.view.simulation.updateSurfaces(local, elapsed: elapsed)
            o.view.needsDisplay = true; o.panel.orderFrontRegardless()
        }
        status(settings.accumulateOnDock && !DockAccessibility.isTrusted
            ? "Snow on windows · Accessibility required for Dock snow" : "Snow tracking · \(windows.count) windows")
    }
    private func status(_ value: String) {
        guard lastStatus != value else { return }; lastStatus = value; onStatus?(value)
    }
}
