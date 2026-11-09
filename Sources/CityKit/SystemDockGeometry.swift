import Foundation

/// A read-only AX observation. Missing bounds are preserved, not guessed.
public struct SystemDockItem: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case application, separator, trash, other }
    public var index: Int
    public var role: String
    public var subrole: String
    public var title: String
    public var axFrame: CGRect?

    public init(index: Int, role: String, subrole: String, title: String, axFrame: CGRect?) {
        self.index = index; self.role = role; self.subrole = subrole
        self.title = title; self.axFrame = axFrame
    }
    public var kind: Kind {
        let raw = (role + " " + subrole).lowercased()
        if raw.contains("separator") || raw.contains("splitter") { return .separator }
        if raw.contains("trash") { return .trash }
        if raw.contains("applicationdockitem") { return .application }
        return .other
    }
}

public enum SystemDockOrientation: String, Codable, Sendable { case bottom, left, right }

/// Pure, testable mapping between AX (top-left) and Cocoa (bottom-left).
public enum SystemDockGeometry {
    public static func cocoaFrame(axFrame: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: axFrame.minX, y: primaryMaxY - axFrame.maxY,
               width: axFrame.width, height: axFrame.height)
    }

    public static func valid(_ rect: CGRect) -> Bool {
        [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy { $0.isFinite }
            && rect.width > 0 && rect.height > 0
    }

    /// The screen containing the largest visible area of the observed items.
    /// A hidden Dock's offscreen items produce no plan; no stale panel remains.
    public static func screenIndex(items: [CGRect], screens: [CGRect]) -> Int? {
        let areas = screens.map { screen in
            items.filter(valid).reduce(CGFloat(0)) { total, item in
                let r = item.intersection(screen)
                return total + (r.isNull ? 0 : r.width * r.height)
            }
        }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else { return nil }
        return best
    }

    public struct Plan: Equatable, Sendable {
        public let panelFrame: CGRect
        public let visibleItems: [CGRect]
    }

    /// Include real icon hit regions, so clicking through the outlines actually
    /// tests input forwarding. Also reserve an inward strip for alignment ticks.
    public static func plan(items: [CGRect], screen: CGRect, orientation: SystemDockOrientation,
                            stripHeight: CGFloat = 90) -> Plan? {
        let visible = items.filter { valid($0) && $0.intersects(screen) }
        guard let first = visible.first else { return nil }
        let iconBounds = visible.dropFirst().reduce(first) { $0.union($1) }.intersection(screen)
        guard valid(iconBounds) else { return nil }
        let height = max(0, stripHeight)
        let expanded: CGRect
        switch orientation {
        case .bottom: expanded = CGRect(x: iconBounds.minX, y: iconBounds.minY, width: iconBounds.width, height: iconBounds.height + height)
        case .left: expanded = CGRect(x: iconBounds.minX, y: iconBounds.minY, width: iconBounds.width + height, height: iconBounds.height)
        case .right: expanded = CGRect(x: iconBounds.minX - height, y: iconBounds.minY, width: iconBounds.width + height, height: iconBounds.height)
        }
        return Plan(panelFrame: expanded.intersection(screen), visibleItems: visible)
    }
}
