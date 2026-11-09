import Foundation

public enum BuildingStyle: String, Codable, CaseIterable, Sendable {
    case office, glassTower, warehouse, concertHall, clockTower, library, shop
    case serverCenter, postOffice, communications, gallery

    public static func defaultStyle(bundleID: String?) -> Self {
        switch bundleID {
        case "com.apple.finder": return .warehouse
        case "com.apple.Safari": return .glassTower
        case "com.apple.Music": return .concertHall
        case "com.apple.Terminal": return .serverCenter
        case "com.apple.iCal": return .clockTower
        case "com.apple.mail": return .postOffice
        case "com.apple.MobileSMS": return .communications
        case "com.apple.Photos": return .gallery
        case "com.apple.Notes": return .library
        default: return .office
        }
    }
}

public struct BuildingOverride: Codable, Equatable, Sendable {
    public var style: BuildingStyle?
    public var color: String?
    public init(style: BuildingStyle? = nil, color: String? = nil) {
        self.style = style; self.color = color
    }
}

public struct CitySettings: Codable, Equatable, Sendable {
    public enum Size: String, Codable, CaseIterable, Sendable {
        case small, normal, large
        public var height: Double { self == .small ? 66 : self == .large ? 116 : 90 }
    }
    public enum TimeMode: String, Codable, CaseIterable, Sendable {
        case automatic, day, night
        public func isNight(hour: Int) -> Bool {
            self == .night || (self == .automatic && (hour < 7 || hour >= 18))
        }
    }
    public enum Density: String, Codable, CaseIterable, Sendable {
        case off, low, normal, high
        public var count: Int { switch self { case .off: return 0; case .low: return 1; case .normal: return 3; case .high: return 6 } }
    }
    public enum Quality: String, Codable, CaseIterable, Sendable {
        case low, normal, high
        public var fps: Double { self == .low ? 15 : self == .high ? 60 : 30 }
    }
    public var enabled = true
    public var decorations = true
    public var size: Size = .normal
    public var timeMode: TimeMode = .automatic
    public var lightIntensity = 0.8
    public var defaultStyle: BuildingStyle = .office
    public var citizensEnabled = true
    public var citizenDensity: Density = .normal
    public var trafficEnabled = true
    public var trafficDensity: Density = .normal
    public var quality: Quality = .normal
    public var reduceMotion = false
    public var lowPower = false
    public var pauseWhenNotVisible = true
    public var buildings: [String: BuildingOverride] = [:]
    public init() {}

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled, decorations, size, timeMode, lightIntensity, defaultStyle
        case citizensEnabled, citizenDensity, trafficEnabled, trafficDensity
        case quality, reduceMotion, lowPower, pauseWhenNotVisible, buildings
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        decorations = try c.decodeIfPresent(Bool.self, forKey: .decorations) ?? decorations
        size = try c.decodeIfPresent(Size.self, forKey: .size) ?? size
        timeMode = try c.decodeIfPresent(TimeMode.self, forKey: .timeMode) ?? timeMode
        lightIntensity = min(1, max(0, try c.decodeIfPresent(Double.self, forKey: .lightIntensity) ?? lightIntensity))
        defaultStyle = try c.decodeIfPresent(BuildingStyle.self, forKey: .defaultStyle) ?? defaultStyle
        citizensEnabled = try c.decodeIfPresent(Bool.self, forKey: .citizensEnabled) ?? citizensEnabled
        citizenDensity = try c.decodeIfPresent(Density.self, forKey: .citizenDensity) ?? citizenDensity
        trafficEnabled = try c.decodeIfPresent(Bool.self, forKey: .trafficEnabled) ?? trafficEnabled
        trafficDensity = try c.decodeIfPresent(Density.self, forKey: .trafficDensity) ?? trafficDensity
        quality = try c.decodeIfPresent(Quality.self, forKey: .quality) ?? quality
        reduceMotion = try c.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? reduceMotion
        lowPower = try c.decodeIfPresent(Bool.self, forKey: .lowPower) ?? lowPower
        pauseWhenNotVisible = try c.decodeIfPresent(Bool.self, forKey: .pauseWhenNotVisible) ?? pauseWhenNotVisible
        buildings = try c.decodeIfPresent([String: BuildingOverride].self, forKey: .buildings) ?? buildings
    }
}
