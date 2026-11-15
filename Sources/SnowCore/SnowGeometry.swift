import Foundation

/// Physics uses logical points, with y increasing downward (the CG convention).
public struct SnowRect: Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var right: Double { x + width }
    public var bottom: Double { y + height }
    public var valid: Bool {
        [x, y, width, height, right, bottom].allSatisfy { $0.isFinite && abs($0) <= 100_000 }
            && width > 0 && height > 0
    }
    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px < right && py >= y && py < bottom
    }
}

public struct SnowSurface: Equatable, Sendable {
    public enum Kind: Sendable { case window, dock }
    public var id: UInt64
    public var frame: SnowRect
    public var kind: Kind
    public init(id: UInt64, frame: SnowRect, kind: Kind = .window) {
        self.id = id; self.frame = frame; self.kind = kind
    }
}

public enum SnowScene {
    public static let maximumSurfaces = 64
    /// Preserve front-to-back order, reject bad geometry and duplicate IDs.
    public static func validated(_ surfaces: [SnowSurface]) -> [SnowSurface] {
        var seen = Set<UInt64>()
        return Array(surfaces.prefix(512).filter { $0.frame.valid && seen.insert($0.id).inserted }.prefix(maximumSurfaces))
    }
    public static func local(_ surfaces: [SnowSurface], display: SnowRect) -> [SnowSurface] {
        guard display.valid else { return [] }
        return validated(surfaces).filter {
            $0.frame.right > display.x && $0.frame.x < display.right
                && $0.frame.bottom > display.y && $0.frame.y < display.bottom
        }.map {
            var s = $0; s.frame.x -= display.x; s.frame.y -= display.y; return s
        }
    }
    public static func covered(x: Double, y: Double, in surfaces: [SnowSurface], before index: Int) -> Bool {
        surfaces.prefix(max(0, index)).contains { $0.frame.contains(x: x, y: y) }
    }
    public static func fullscreen(in surfaces: [SnowSurface], width: Double, height: Double) -> Bool {
        guard let front = surfaces.first(where: { $0.kind == .window }) else { return false }
        let r = front.frame
        return r.x <= 1 && r.y <= 1 && r.right >= width - 1 && r.bottom >= height - 1
    }
}
