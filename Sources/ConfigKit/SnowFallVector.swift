import Foundation

/// Screen coordinates: right = +x, down = +y; magnitude is points per second.
public struct SnowFallVector: Codable, Equatable, Sendable {
    public static let maximumSpeed = 180.0
    public let x: Double
    public let y: Double
    public var speed: Double { hypot(x, y) }

    public init(x: Double = 0, y: Double = 32) {
        guard x.isFinite, y.isFinite else { self.x = 0; self.y = 32; return }
        let largest = max(abs(x), abs(y))
        guard largest > 0 else { self.x = 0; self.y = 0; return }
        // Normalize before taking a length, so even finite near-Double.max input is safe.
        let nx = x / largest, ny = y / largest, length = hypot(nx, ny)
        if largest > Self.maximumSpeed / length {
            self.x = nx / length * Self.maximumSpeed; self.y = ny / length * Self.maximumSpeed
        } else { self.x = x; self.y = y }
    }
    public static func fromControl(x: Double, y: Double, radius: Double) -> Self {
        guard radius.isFinite, radius > 0, x.isFinite, y.isFinite else { return Self() }
        let largest = max(abs(x), abs(y))
        if largest > radius {
            let nx = x / largest, ny = y / largest, length = hypot(nx, ny)
            return Self(x: nx / length * maximumSpeed, y: ny / length * maximumSpeed)
        }
        return Self(x: x / radius * maximumSpeed, y: y / radius * maximumSpeed)
    }
    public func withSpeed(_ value: Double) -> Self {
        guard value.isFinite else { return self }
        let magnitude = min(Self.maximumSpeed, max(0, value))
        guard speed > 0.001 else { return Self(x: 0, y: magnitude) }
        return Self(x: x / speed * magnitude, y: y / speed * magnitude)
    }
    public func rotated(degrees: Double) -> Self {
        guard degrees.isFinite else { return self }
        let angle = degrees.truncatingRemainder(dividingBy: 360) * .pi / 180
        return Self(x: x * cos(angle) - y * sin(angle), y: x * sin(angle) + y * cos(angle))
    }
    private enum CodingKeys: String, CodingKey { case x, y }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decodeIfPresent(Double.self, forKey: .x) ?? 0,
                  y: try c.decodeIfPresent(Double.self, forKey: .y) ?? 32)
    }
}
