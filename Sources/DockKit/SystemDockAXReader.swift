import Foundation
import ApplicationServices
import CoreGraphics
import CityKit

public struct SystemDockSnapshot: Codable {
    public let pid: pid_t
    public let orientation: String?
    public let tileSize: Double?
    public let autohide: Bool?
    public let axListFrame: CGRect?
    public let items: [SystemDockItem]
    public let dockWindowFrame: CGRect?
    public let dockWindowLayer: Int?
    public let incomplete: Bool
}

public enum SystemDockReadError: Error, CustomStringConvertible {
    case permissionRequired, listUnavailable(Int32), tooManyElements, timedOut
    public var description: String {
        switch self {
        case .permissionRequired: return "Accessibility permission required; no Dock geometry was read."
        case .listUnavailable(let code): return "No readable Dock AXList (AX error \(code)). Reveal the Dock and retry."
        case .tooManyElements: return "Dock AX traversal reached its safety limit; result is incomplete."
        case .timedOut: return "Dock AX read exceeded its time budget; waiting for fresh geometry."
        }
    }
}

/// Shared read-only tracker. No AX actions, preference writes,
/// event injection, application launching, or private Dock process modification.
public enum SystemDockAXReader {
    public static func read(pid: pid_t) throws -> SystemDockSnapshot {
        guard AXIsProcessTrusted() else { throw SystemDockReadError.permissionRequired }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.6
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15) // client timeout, not a Dock setting
        var queue: [(AXUIElement, Int)] = [(app, 0)]
        var offset = 0
        var list: AXUIElement?
        var lastError: AXError = .success
        while offset < queue.count && offset < 256 {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw SystemDockReadError.timedOut }
            let (element, depth) = queue[offset]; offset += 1
            if string(element, kAXRoleAttribute) == kAXListRole as String { list = element; break }
            if depth < 5 {
                var children: CFTypeRef?
                lastError = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
                let childList = children as? [AXUIElement] ?? []
                queue.append(contentsOf: childList.prefix(max(0, 256 - queue.count)).map { ($0, depth + 1) })
            }
        }
        guard let list else {
            if offset >= 256 { throw SystemDockReadError.tooManyElements }
            throw SystemDockReadError.listUnavailable(lastError.rawValue)
        }
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let children = value as? [AXUIElement] else {
            throw SystemDockReadError.listUnavailable(result.rawValue)
        }
        var items: [SystemDockItem] = []
        for (index, child) in children.prefix(512).enumerated() {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw SystemDockReadError.timedOut }
            items.append(SystemDockItem(index: index, role: string(child, kAXRoleAttribute),
                           subrole: string(child, kAXSubroleAttribute),
                           title: string(child, kAXTitleAttribute), axFrame: frame(child),
                           applicationURL: applicationURL(child)))
        }
        guard ProcessInfo.processInfo.systemUptime < deadline else { throw SystemDockReadError.timedOut }
        let listFrame = frame(list)
        let window = dockWindow(pid: pid, listFrame: listFrame)
        return SystemDockSnapshot(pid: pid,
            // An absent preference uses macOS's factory-default bottom Dock.
            orientation: (preference("orientation") as? String) ?? "bottom",
            tileSize: (preference("tilesize") as? NSNumber)?.doubleValue,
            autohide: (preference("autohide") as? NSNumber)?.boolValue,
            axListFrame: listFrame, items: items, dockWindowFrame: window?.0,
            dockWindowLayer: window?.1, incomplete: children.count > 512)
    }

    private static func preference(_ key: String) -> CFPropertyList? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString)
    }
    private static func applicationURL(_ element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value) == .success else { return nil }
        let url = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
        guard let url, url.isFileURL, url.pathExtension.lowercased() == "app" else { return nil }
        return url.standardizedFileURL
    }
    private static func string(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return "" }
        return value as? String ?? ""
    }
    private static func frame(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let p = position, let s = size,
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point),
              AXValueGetValue(s as! AXValue, .cgSize, &dimensions) else { return nil }
        let rect = CGRect(origin: point, size: dimensions)
        return SystemDockGeometry.valid(rect) ? rect : nil
    }
    private static func dockWindow(pid: pid_t, listFrame: CGRect?) -> (CGRect, Int)? {
        guard let listFrame,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        return info.compactMap { row -> (CGRect, Int)? in
            guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  let bounds = row[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  let layer = row[kCGWindowLayer as String] as? Int,
                  layer >= Int(CGWindowLevelForKey(.dockWindow)), rect.intersects(listFrame) else { return nil }
            return (rect, layer)
        }.max { a, b in
            let x = a.0.intersection(listFrame), y = b.0.intersection(listFrame)
            return x.width * x.height < y.width * y.height
        }
    }
}
