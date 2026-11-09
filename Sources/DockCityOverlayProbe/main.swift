import AppKit
import ApplicationServices
import DockKit
import CityKit

// Isolated feasibility probe. It never starts DockmanController or DockPanel.
struct Options {
    var once = false
    var requestAccess = false
    var logChanges = false
    var interval = 0.2
    var level = Int(CGWindowLevelForKey(.dockWindow)) + 1
    init() {
        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--once": once = true
            case "--request-access": requestAccess = true
            case "--log-changes": logChanges = true
            case "--interval":
                i += 1
                guard i < args.count, let value = Double(args[i]), value.isFinite, (0.1...2).contains(value) else { Self.usage(64) }
                interval = value
            case "--level":
                i += 1
                guard i < args.count, let value = Int(args[i]), (20...30).contains(value) else { Self.usage(64) }
                level = value
            case "--help", "-h": Self.usage(0)
            default: Self.usage(64)
            }
            i += 1
        }
    }
    static func usage(_ code: Int32) -> Never {
        print("Usage: dock-city-overlay-probe [--once] [--request-access] [--log-changes] [--interval 0.1...2] [--level 20...30]")
        exit(code)
    }
}

func log(_ message: String) { print(message); fflush(stdout) }

struct ProbeReport: Encodable {
    let snapshot: SystemDockSnapshot
    let primaryMaxY: CGFloat
    let cocoaFrames: [CGRect?]
    let itemKinds: [String]
    let configuredOverlayLevel: Int
    let observedOverlayLevel: Int?
    let overlayFrame: CGRect?
    let ignoresMouseEvents: Bool
    let canBecomeKey: Bool
    let warning: String
}

final class ProbePanel: NSPanel {
    init(level: Int) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true; hidesOnDeactivate = false
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true
        self.level = NSWindow.Level(rawValue: level)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ProbeView: NSView {
    var items: [(SystemDockItem, CGRect)] = []
    var orientation: SystemDockOrientation = .bottom
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for (item, frame) in items {
            let tint: NSColor = item.kind == .separator ? .systemOrange : item.kind == .trash ? .systemPink : .systemCyan
            tint.withAlphaComponent(0.8).setStroke()
            let outline = NSBezierPath(rect: frame.insetBy(dx: 0.5, dy: 0.5)); outline.lineWidth = 1; outline.stroke()
            let from: NSPoint, to: NSPoint
            switch orientation {
            case .bottom: from = NSPoint(x: frame.midX, y: frame.maxY); to = NSPoint(x: frame.midX, y: min(bounds.maxY - 20, frame.maxY + 60))
            case .left: from = NSPoint(x: frame.maxX, y: frame.midY); to = NSPoint(x: min(bounds.maxX - 20, frame.maxX + 60), y: frame.midY)
            case .right: from = NSPoint(x: frame.minX, y: frame.midY); to = NSPoint(x: max(20, frame.minX - 60), y: frame.midY)
            }
            let tick = NSBezierPath(); tick.move(to: from); tick.line(to: to); tick.stroke()
            let label = "\(item.index) \(item.kind.rawValue)"
            let textPoint = NSPoint(x: min(max(0, to.x - 18), max(0, bounds.width - 72)), y: min(max(0, to.y + 2), max(0, bounds.height - 12)))
            (label as NSString).draw(at: textPoint, withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: tint,
                .backgroundColor: NSColor.black.withAlphaComponent(0.7),
            ])
        }
    }
}

final class ProbeController: NSObject, NSApplicationDelegate {
    private let options: Options
    private var panel: ProbePanel!
    private let drawing = ProbeView()
    private var timer: Timer?
    private var statusItem: NSStatusItem?
    private var busy = false
    private var permissionNoticeShown = false
    private var lastItems: [SystemDockItem] = []
    private var lastMessage = ""
    private var reported = false

    init(options: Options) { self.options = options }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = ProbePanel(level: options.level)
        panel.contentView = drawing
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Dock Probe"
        let menu = NSMenu()
        let help = NSMenuItem(title: "Accessibility settings…", action: #selector(openAccessibility), keyEquivalent: "")
        help.target = self; menu.addItem(help)
        let quit = NSMenuItem(title: "Quit probe", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit); statusItem?.menu = menu
        log("Dock overlay probe: read-only AX, \(options.interval)s poll, configured level \(options.level). Click/drag/right-click verification is MANUAL.")
        if options.requestAccess { AXWindowControl.requestTrust() }
        poll()
        let t = Timer(timeInterval: options.interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common); timer = t
    }

    private func poll() {
        guard !busy else { return }
        guard AXWindowControl.isTrusted else {
            panel.orderOut(nil); state("Waiting for Accessibility permission")
            if !permissionNoticeShown {
                permissionNoticeShown = true
                let alert = NSAlert()
                alert.messageText = "Allow Dock geometry access"
                alert.informativeText = "This prototype reads only the real Dock's accessibility item labels, roles and rectangles. It does not change the Dock or intercept input. Without permission it shows no overlay or replacement Dock. Enable this probe in Privacy & Security → Accessibility, then return here."
                alert.addButton(withTitle: "Request access")
                alert.addButton(withTitle: "Open settings")
                alert.addButton(withTitle: "Quit")
                NSApp.activate(ignoringOtherApps: true)
                let result = alert.runModal()
                if result == .alertFirstButtonReturn { AXWindowControl.requestTrust() }
                else if result == .alertSecondButtonReturn { openAccessibility() }
                else { quit() }
            }
            return
        }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            panel.orderOut(nil); state("Dock process unavailable"); return
        }
        busy = true
        let pid = dock.processIdentifier
        // AX calls have a bounded timeout and never queue overlapping polls or
        // block the AppKit event loop. Permission revocation hides the overlay.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { try SystemDockAXReader.read(pid: pid) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.busy = false
                switch result {
                case .success(let snapshot): self.apply(snapshot)
                case .failure(let error): self.panel.orderOut(nil); self.state(String(describing: error))
                }
            }
        }
    }

    private func apply(_ snapshot: SystemDockSnapshot) {
        guard AXWindowControl.isTrusted else { panel.orderOut(nil); return }
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        let pairs = snapshot.items.compactMap { item -> (SystemDockItem, CGRect)? in
            guard let rect = item.axFrame else { return nil }
            return (item, SystemDockGeometry.cocoaFrame(axFrame: rect, primaryMaxY: primaryMaxY))
        }
        let screens = NSScreen.screens
        guard !snapshot.incomplete,
              let raw = snapshot.orientation, let orientation = SystemDockOrientation(rawValue: raw),
              let index = SystemDockGeometry.screenIndex(items: pairs.map { $0.1 }, screens: screens.map(\.frame)),
              let plan = SystemDockGeometry.plan(items: pairs.map { $0.1 }, screen: screens[index].frame, orientation: orientation) else {
            panel.orderOut(nil); state("No complete visible Dock geometry / orientation. Reveal the Dock; no positions are guessed.")
            return
        }
        if panel.frame != plan.panelFrame { panel.setFrame(plan.panelFrame, display: true) }
        drawing.orientation = orientation
        drawing.items = pairs.filter { $0.1.intersects(screens[index].frame) }.map { item, rect in
            (item, rect.offsetBy(dx: -plan.panelFrame.minX, dy: -plan.panelFrame.minY))
        }
        drawing.needsDisplay = true
        panel.orderFrontRegardless()
        state("\(snapshot.items.count) AX children · level \(options.level) · click-through configured")
        if !reported || (options.logChanges && snapshot.items != lastItems) {
            emitReport(snapshot, panel: panel, primaryMaxY: primaryMaxY, configuredLevel: options.level)
            reported = true
        }
        lastItems = snapshot.items
    }

    private func state(_ message: String) {
        statusItem?.button?.toolTip = message
        if message != lastMessage { log(message); lastMessage = message }
    }
    @objc private func openAccessibility() {
        // Opens the permission UI only. No permission or Dock setting is changed.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); panel?.orderOut(nil) }
}

func emitReport(_ snapshot: SystemDockSnapshot, panel: ProbePanel?, primaryMaxY: CGFloat, configuredLevel: Int) {
    var observed: Int?
    if let panel, let rows = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(panel.windowNumber)) as? [[String: Any]] {
        observed = rows.first?[kCGWindowLayer as String] as? Int
    }
    let report = ProbeReport(snapshot: snapshot, primaryMaxY: primaryMaxY,
        cocoaFrames: snapshot.items.map { $0.axFrame.map { SystemDockGeometry.cocoaFrame(axFrame: $0, primaryMaxY: primaryMaxY) } },
        itemKinds: snapshot.items.map { $0.kind.rawValue }, configuredOverlayLevel: configuredLevel,
        observedOverlayLevel: observed, overlayFrame: panel?.frame,
        ignoresMouseEvents: panel?.ignoresMouseEvents ?? false, canBecomeKey: panel?.canBecomeKey ?? false,
        warning: "AX-only observations: absent separators/trash or missing bounds are not inferred. Input forwarding and visual stacking require manual verification. --once does not create a panel.")
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do { log(String(decoding: try encoder.encode(report), as: UTF8.self)) }
    catch { log("Report encoding failed: \(error)") }
}

let options = Options()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if options.once {
    if options.requestAccess { AXWindowControl.requestTrust() }
    guard AXWindowControl.isTrusted else {
        log("Accessibility permission required. Launch the packaged probe to grant access; no synthetic coordinates or overlay were produced."); exit(2)
    }
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
        log("Dock process not running."); exit(3)
    }
    do {
        let snapshot = try SystemDockAXReader.read(pid: dock.processIdentifier)
        emitReport(snapshot, panel: nil, primaryMaxY: NSScreen.screens.first?.frame.maxY ?? 0, configuredLevel: options.level)
        exit(snapshot.incomplete || !snapshot.items.contains(where: { $0.axFrame != nil }) ? 4 : 0)
    } catch { log(String(describing: error)); exit(4) }
}
let delegate = ProbeController(options: options)
app.delegate = delegate
app.run()
