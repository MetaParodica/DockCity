import AppKit
import QuartzCore
import ConfigKit
import CityKit

/// A click-through child of the real DockPanel. No event monitors or second Dock.
final class CityPanel: NSPanel {
    private weak var dock: DockPanel?
    private let scene = CityScene()
    private var timer: Timer?
    private var settings = CitySettings()
    private var tiles: [CityTile] = []
    private var edge: Appearance.Edge = .bottom
    private var lastTick = Date()
    private var lastNight: Bool?
    private var motionWasAllowed = false

    init(dock: DockPanel) {
        self.dock = dock
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true; hidesOnDeactivate = false
        isFloatingPanel = true
        collectionBehavior = dock.collectionBehavior
        let view = NSView(); view.wantsLayer = true
        view.layer?.addSublayer(scene.root)
        contentView = view
        dock.addChildWindow(self, ordered: .above)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func configure(tiles: [CityTile], settings: CitySettings, edge: Appearance.Edge) {
        self.tiles = tiles; self.settings = settings; self.edge = edge
        sync()
        timer?.invalidate(); timer = nil
        guard settings.enabled else { orderOut(nil); return }
        lastTick = Date()
        // Static scenes only wake for clock/daylight, never a continuous frame loop.
        let interval = motionAllowed ? 1 / settings.quality.fps : 1.0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // AppKit updates always stay on the main queue, including SDKs whose
            // Timer callback is annotated Sendable.
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common); timer = t
    }

    private var reduced: Bool {
        settings.reduceMotion || settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var motionAllowed: Bool {
        !reduced && ((settings.citizensEnabled && settings.citizenDensity != .off)
            || (settings.trafficEnabled && settings.trafficDensity != .off))
    }

    func sync() {
        guard let dock, settings.enabled else { orderOut(nil); return }
        let f = dock.frame
        let screen = dock.screen?.frame ?? f
        let desired = CGFloat(settings.size.height)
        let available: CGFloat
        switch edge {
        case .bottom: available = screen.maxY - f.maxY
        case .top: available = f.minY - screen.minY
        case .left: available = screen.maxX - f.maxX
        case .right: available = f.minX - screen.minX
        }
        let height = max(0, min(desired, available))
        var rect: NSRect
        switch edge {
        case .bottom: rect = NSRect(x: f.minX, y: f.maxY, width: f.width, height: height)
        case .top: rect = NSRect(x: f.minX, y: f.minY - height, width: f.width, height: height)
        case .left: rect = NSRect(x: f.maxX, y: f.minY, width: height, height: f.height)
        case .right: rect = NSRect(x: f.minX - height, y: f.minY, width: height, height: f.height)
        }
        if frame != rect { setFrame(rect, display: true) }
        alphaValue = dock.alphaValue
        let length = edge.isVertical ? rect.height : rect.width
        let night = settings.timeMode.isNight(hour: Calendar.current.component(.hour, from: Date()))
        let scale = dock.backingScaleFactor
        CATransaction.begin(); CATransaction.setDisableActions(true)
        scene.root.bounds = CGRect(x: 0, y: 0, width: length, height: height)
        scene.root.position = CGPoint(x: rect.width / 2, y: rect.height / 2)
        scene.root.setAffineTransform(CGAffineTransform(rotationAngle: edge == .left ? -.pi / 2 : edge == .right ? .pi / 2 : edge == .top ? .pi : 0))
        let mapped = tiles.map { tile -> CityTile in
            var t = tile
            if edge == .left || edge == .top { t.center = Double(length) - t.center }
            return t
        }
        var effective = settings
        effective.reduceMotion = reduced
        scene.configure(tiles: mapped, settings: effective, night: night, scale: scale)
        CATransaction.commit()
        lastNight = night
        if dock.isVisible && height > 0 { orderFrontRegardless() } else { orderOut(nil) }
    }

    private func tick() {
        guard let dock else { stop(); return }
        let now = Date(); let dt = now.timeIntervalSince(lastTick); lastTick = now
        let visible = dock.isVisible && dock.alphaValue > 0.01 && dock.occlusionState.contains(.visible)
        if settings.pauseWhenNotVisible && !visible { return }
        let night = settings.timeMode.isNight(hour: Calendar.current.component(.hour, from: now))
        if night != lastNight { sync() }
        alphaValue = dock.alphaValue
        let moving = motionAllowed
        if moving != motionWasAllowed {
            motionWasAllowed = moving
            configure(tiles: tiles, settings: settings, edge: edge)
        }
        scene.update(seconds: moving ? dt : 0, date: now, animate: !reduced)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        dock?.removeChildWindow(self); orderOut(nil)
    }
    deinit { timer?.invalidate() }
}
