import AppKit
import QuartzCore
import ConfigKit
import CityKit

/// Decoration only: it never becomes key or receives Dock input.
final class TrackedCityPanel: NSPanel {
    var onVisibilityChanged: ((Bool, CGRect) -> Void)?
    private let scene = CityScene()
    private var layout: TrackedCityLayout?
    private var tiles: [CityTile] = []
    private var settings = CitySettings()
    private var lastNight: Bool?
    private var lastReduced = false
    private var lastUpdate = Date()
    private var slide = DockSlide()
    private var wantsVisible = false
    func hover(tileID: String?) { scene.hover(tileID: reduced ? nil : tileID) }
    func launched(tileIDs: Set<String>) { if !reduced { scene.launch(tileIDs: tileIDs) } }
    var onRenderedVisibilityChanged: ((Bool, CGRect) -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = true
        ignoresMouseEvents = true; hidesOnDeactivate = false; isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + (CommandLine.arguments.contains("--city-below-dock") ? -1 : 1))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(); view.wantsLayer = true
        view.layer?.addSublayer(scene.root); contentView = view
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func orderOut(_ sender: Any?) {
        wantsVisible = false; slide = DockSlide()
        super.orderOut(sender); onVisibilityChanged?(isVisible, frame)
        onRenderedVisibilityChanged?(false, frame)
    }
    override func orderFrontRegardless() {
        super.orderFrontRegardless(); onVisibilityChanged?(isVisible, frame)
    }

    private var reduced: Bool {
        settings.reduceMotion || settings.lowPower || ProcessInfo.processInfo.isLowPowerModeEnabled
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func apply(layout: TrackedCityLayout, tiles: [CityTile], settings: CitySettings, duration: Double = 0, delay: Double = 0, reveal: Bool = true) {
        self.layout = layout; self.tiles = tiles; self.settings = settings
        if reveal {
            slide.set(visible: true, now: ProcessInfo.processInfo.systemUptime, delay: reduced ? 0 : delay, duration: reduced ? 0 : duration)
            wantsVisible = true
        }
        positionPanel()
        rebuild()
        if !isVisible && wantsVisible { lastUpdate = Date(); orderFrontRegardless(); positionPanel() }
    }
    func hide(duration: Double) {
        guard wantsVisible else { return }
        wantsVisible = false
        slide.set(visible: false, now: ProcessInfo.processInfo.systemUptime, duration: reduced ? 0 : duration)
        positionPanel()
    }
    private func positionPanel() {
        guard let layout else { return }
        if reduced { slide.finish() }
        let amount = slide.value(at: ProcessInfo.processInfo.systemUptime)
        let screen = NSScreen.screens.first { $0.frame.intersects(layout.frame) }?.frame ?? layout.frame
        var f = layout.frame
        switch layout.orientation {
        case .bottom: f.origin.y -= (layout.frame.maxY - screen.minY + 1) * (1 - amount)
        case .left: f.origin.x -= (layout.frame.maxX - screen.minX + 1) * (1 - amount)
        case .right: f.origin.x += (screen.maxX - layout.frame.minX + 1) * (1 - amount)
        }
        if frame != f { setFrame(f, display: true) }
        onRenderedVisibilityChanged?(isVisible && amount > 0 && f.intersects(screen), f)
        if !wantsVisible && amount <= 0 { orderOut(nil) }
    }

    private func rebuild() {
        guard let layout else { return }
        let night = settings.timeMode.isNight(hour: Calendar.current.component(.hour, from: Date()))
        var effective = settings; effective.reduceMotion = reduced
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency { effective.background = .sky }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        scene.root.bounds = CGRect(x: 0, y: 0, width: layout.length, height: layout.depth)
        scene.root.position = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let angle: CGFloat = layout.orientation == .left ? -.pi / 2 : layout.orientation == .right ? .pi / 2 : 0
        scene.root.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        let plazas = zip(layout.items, layout.itemFrames).compactMap { item, rect -> ClosedRange<Double>? in
            guard item.kind == .separator else { return nil }
            let center = layout.center(of: rect)
            let width = Double(layout.orientation == .bottom ? rect.width : rect.height)
            return (center - width / 2)...(center + width / 2)
        }
        scene.configure(tiles: tiles, settings: effective, night: night, scale: backingScaleFactor, plazas: plazas)
        CATransaction.commit()
        lastNight = night; lastReduced = reduced
    }

    func tick() {
        guard wantsVisible || isVisible else { lastUpdate = Date(); return }
        positionPanel()
        let now = Date()
        guard isVisible else { lastUpdate = now; return }
        let interval = reduced ? 1.0 : 1 / settings.quality.fps
        guard now.timeIntervalSince(lastUpdate) >= interval else { return }
        if lastNight != settings.timeMode.isNight(hour: Calendar.current.component(.hour, from: now)) || lastReduced != reduced { rebuild() }
        scene.update(seconds: reduced ? 0 : now.timeIntervalSince(lastUpdate), date: now, animate: !reduced)
        lastUpdate = now
    }
}
