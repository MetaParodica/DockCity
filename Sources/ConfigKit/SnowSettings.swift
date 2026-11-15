import Foundation

public struct SnowSettings: Codable, Equatable, Sendable {
    public enum Intensity: String, Codable, CaseIterable, Sendable {
        case light, steady, flurry
        public var flakesPerSecond: Double { self == .light ? 18 : self == .steady ? 40 : 75 }
    }
    public var enabled = true
    public var intensity: Intensity = .light
    public var fallVector = SnowFallVector()
    public var accumulateOnWindows = true
    public var accumulateOnDock = true
    public var maximumDepth = 16.0
    public var reduceMotion = false
    public var lowPower = false
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case enabled, intensity, fallVector, accumulateOnWindows, accumulateOnDock, maximumDepth, reduceMotion, lowPower
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        intensity = try c.decodeIfPresent(Intensity.self, forKey: .intensity) ?? intensity
        fallVector = try c.decodeIfPresent(SnowFallVector.self, forKey: .fallVector) ?? fallVector
        accumulateOnWindows = try c.decodeIfPresent(Bool.self, forKey: .accumulateOnWindows) ?? accumulateOnWindows
        accumulateOnDock = try c.decodeIfPresent(Bool.self, forKey: .accumulateOnDock) ?? accumulateOnDock
        let depth = try c.decodeIfPresent(Double.self, forKey: .maximumDepth) ?? maximumDepth
        maximumDepth = depth.isFinite ? min(30, max(2, depth)) : 16
        reduceMotion = try c.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? reduceMotion
        lowPower = try c.decodeIfPresent(Bool.self, forKey: .lowPower) ?? lowPower
    }
}
