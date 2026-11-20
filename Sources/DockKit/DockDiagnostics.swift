import AppKit
import QuartzCore
import CityKit

/// Opt-in stdout diagnostics. No files, titles, network traffic or event taps.
final class DockDiagnostics {
    let enabled = CommandLine.arguments.contains("--diagnose-dock")
    private let origin = CACurrentMediaTime()
    private var edgeTime: Double?
    private var wasAtEdge = false
    private var lastVisible: Bool?
    private var lastRendered: Bool?
    func rendered(_ visible: Bool, frame: CGRect) {
        guard enabled, lastRendered != visible else { return }
        lastRendered = visible
        event(visible ? "city_first_visible_geometry" : "city_no_visible_geometry", fields: ["frame": rect(frame)])
    }

    func pointer(_ point: CGPoint, orientation: String?) {
        guard enabled else { return }
        let edge = NSScreen.screens.contains { screen in
            let f = screen.frame
            guard f.insetBy(dx: -1, dy: -1).contains(point) else { return false }
            switch orientation {
            case "left": return point.x <= f.minX + 2
            case "right": return point.x >= f.maxX - 2
            default: return point.y <= f.minY + 2
            }
        }
        if edge != wasAtEdge {
            wasAtEdge = edge
            if edge { edgeTime = CACurrentMediaTime() }
            event(edge ? "pointer_edge_enter_sampled" : "pointer_edge_exit_sampled")
        }
    }
    func visibility(_ visible: Bool, frame: CGRect) {
        guard enabled, lastVisible != visible else { return }
        lastVisible = visible
        event(visible ? "city_order_front" : "city_order_out", fields: ["frame": rect(frame)])
    }
    func snapshot(_ snapshot: SystemDockSnapshot, readMS: Double) {
        guard enabled else { return }
        let screens = NSScreen.screens.map(\.frame), primaryY = screens.first?.maxY ?? 0
        let orientation = snapshot.orientation.flatMap(SystemDockOrientation.init(rawValue:)) ?? .bottom
        let dockVisible = snapshot.dockWindowFrame.map {
            TrackedCityLayout.dockWindowIsVisible($0, primaryMaxY: primaryY, screens: screens, orientation: orientation)
        } ?? false
        let frames = snapshot.items.compactMap(\.axFrame).filter(SystemDockGeometry.valid)
        let axVisible = !snapshot.incomplete && !frames.isEmpty && frames.allSatisfy { rect in
            let f = SystemDockGeometry.cocoaFrame(axFrame: rect, primaryMaxY: primaryY)
            return screens.contains { $0.contains(f) }
        }
        event("ax_snapshot", fields: ["read_ms": readMS, "items": snapshot.items.count,
            "dock_visible": dockVisible, "ax_visible": axVisible,
            "incomplete": snapshot.incomplete, "autohide": snapshot.autohide ?? false,
            "ax_list": snapshot.axListFrame.map { rect($0) as Any } ?? NSNull(),
            "dock_window": snapshot.dockWindowFrame.map { rect($0) as Any } ?? NSNull(),
            "dock_level": snapshot.dockWindowLayer.map { $0 as Any } ?? NSNull()])
        // These are observations, not a claim that a specific window is the label.
        if let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            let windows: [[String: Any]] = rows.compactMap { row in
                guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == snapshot.pid,
                      let raw = row[kCGWindowBounds as String] as? NSDictionary,
                      let f = CGRect(dictionaryRepresentation: raw as CFDictionary),
                      let level = row[kCGWindowLayer as String] as? NSNumber else { return nil }
                return ["owner_pid": snapshot.pid, "level": level, "frame": rect(f)]
            }
            event("dock_owned_windows_unclassified", fields: ["windows": windows])
        }
    }
    func event(_ name: String, fields: [String: Any] = [:]) {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        var row = fields
        row["event"] = name; row["elapsed_ms"] = (now - origin) * 1000
        if let edgeTime { row["since_edge_ms"] = (now - edgeTime) * 1000 }
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        print(String(decoding: data, as: UTF8.self)); fflush(stdout)
    }
    private func rect(_ f: CGRect) -> [String: Double] {
        ["x": f.minX, "y": f.minY, "width": f.width, "height": f.height]
    }
}
