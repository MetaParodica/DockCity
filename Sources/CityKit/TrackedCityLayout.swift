import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Production layout: only the inward strip beside the observed Dock is drawn.
/// AX coordinates stay in points. Missing geometry is never synthesized.
public struct TrackedCityLayout {
    public let frame: CGRect
    public let orientation: SystemDockOrientation
    public let items: [SystemDockItem]
    public let itemFrames: [CGRect]
    public var length: CGFloat { orientation == .bottom ? frame.width : frame.height }
    public var depth: CGFloat { orientation == .bottom ? frame.height : frame.width }

    /// CG window bounds corroborate AX visibility when AX still reports old icons.
    public static func dockWindowIsVisible(_ axFrame: CGRect, primaryMaxY: CGFloat,
                                           screens: [CGRect], orientation: SystemDockOrientation) -> Bool {
        guard SystemDockGeometry.valid(axFrame) else { return false }
        let window = SystemDockGeometry.cocoaFrame(axFrame: axFrame, primaryMaxY: primaryMaxY)
        return screens.contains { screen in
            let visible = window.intersection(screen)
            guard SystemDockGeometry.valid(visible) else { return false }
            return orientation == .bottom ? visible.height > 4 : visible.width > 4
        }
    }

    public static func make(items: [SystemDockItem], primaryMaxY: CGFloat, screens: [CGRect],
                            orientation: SystemDockOrientation, height: CGFloat, gap: CGFloat = 3) -> Self? {
        guard height.isFinite, height > 0, gap.isFinite, gap >= 0 else { return nil }
        let pairs = items.compactMap { item -> (SystemDockItem, CGRect)? in
            guard let ax = item.axFrame, SystemDockGeometry.valid(ax) else { return nil }
            return (item, SystemDockGeometry.cocoaFrame(axFrame: ax, primaryMaxY: primaryMaxY))
        }
        guard let index = SystemDockGeometry.screenIndex(items: pairs.map { $0.1 }, screens: screens) else { return nil }
        let screen = screens[index]
        // Partially hidden icons must not leave a floating city at the screen edge.
        let visible = pairs.filter { screen.contains($0.1) }
        guard let first = visible.first, visible.count == pairs.count else { return nil }
        let bounds = visible.dropFirst().reduce(first.1) { $0.union($1.1) }
        let proposed: CGRect
        switch orientation {
        case .bottom: proposed = CGRect(x: bounds.minX, y: bounds.maxY + gap, width: bounds.width, height: height)
        case .left: proposed = CGRect(x: bounds.maxX + gap, y: bounds.minY, width: height, height: bounds.height)
        case .right: proposed = CGRect(x: bounds.minX - gap - height, y: bounds.minY, width: height, height: bounds.height)
        }
        let frame = proposed.intersection(screen)
        guard SystemDockGeometry.valid(frame) else { return nil }
        return Self(frame: frame, orientation: orientation, items: visible.map { $0.0 }, itemFrames: visible.map { $0.1 })
    }

    public func center(of rect: CGRect) -> Double {
        switch orientation {
        case .bottom: return Double(rect.midX - frame.minX)
        case .left: return Double(frame.maxY - rect.midY)
        case .right: return Double(rect.midY - frame.minY)
        }
    }
}
