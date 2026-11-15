import AppKit
import QuartzCore
import ConfigKit
import CityKit

/// Decoration only: it never becomes key or receives Dock input.
final class TrackedCityPanel: NSPanel {
    private let scene = CityScene()
    private var layout: TrackedCityLayout?
    private var tiles: [CityTile] = []
    private var settings = CitySettings()
    private var lastNight: Bool?
    private var lastReduced = false
    private var lastUpdate = Date()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true; hidesOnDeactivate = false; isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(); view.wantsLayer = true
        view.layer?.addSublayer(scene.root); contentView = view
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private var reduced: Bool {
        settings.reduceMotion || settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func apply(layout: TrackedCityLayout, tiles: [CityTile], settings: CitySettings) {
        self.layout = layout; self.tiles = tiles; self.settings = settings
        if frame != layout.frame { setFrame(layout.frame, display: true) }
        rebuild()
        if !isVisible { lastUpdate = Date(); orderFrontRegardless() }
    }

    private func rebuild() {
        guard let layout else { return }
        let night = settings.timeMode.isNight(hour: Calendar.current.component(.hour, from: Date()))
        var effective = settings; effective.reduceMotion = reduced
        CATransaction.begin(); CATransaction.setDisableActions(true)
        scene.root.bounds = CGRect(x: 0, y: 0, width: layout.length, height: layout.depth)
        scene.root.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let angle: CGFloat = layout.orientation == .left ? -.pi / 2 : layout.orientation == .right ? .pi / 2 : 0
        scene.root.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        scene.configure(tiles: tiles, settings: effective, night: night, scale: backingScaleFactor)
        CATransaction.commit()
        lastNight = night; lastReduced = reduced
    }

    func tick() {
        let now = Date()
        guard isVisible else { lastUpdate = now; return }
        let interval = reduced ? 1.0 : 1 / settings.quality.fps
        guard now.timeIntervalSince(lastUpdate) >= interval else { return }
        if lastNight != settings.timeMode.isNight(hour: Calendar.current.component(.hour, from: now)) || lastReduced != reduced { rebuild() }
        scene.update(seconds: reduced ? 0 : now.timeIntervalSince(lastUpdate), date: now, animate: !reduced)
        lastUpdate = now
    }
}
