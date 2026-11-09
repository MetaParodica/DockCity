import Foundation
import ConfigKit

public enum BuildingActivity: String, Sendable { case inactive, running, active }

public struct CityAppState: Sendable {
    public let bundleID: String?
    public let path: String?
    public let active: Bool
    public init(bundleID: String?, path: String?, active: Bool) {
        self.bundleID = bundleID; self.path = path; self.active = active
    }
    public static func activity(bundleID: String?, path: String, running: [Self]) -> BuildingActivity {
        let matches = running.filter { $0.path == path || (bundleID != nil && $0.bundleID == bundleID) }
        return matches.contains(where: \.active) ? .active : matches.isEmpty ? .inactive : .running
    }
}

/// Geometry comes from the existing dock cells, never a second item layout.
public struct CityTile: Equatable, Sendable {
    public var id: String
    public var bundleID: String?
    public var center: Double
    public var width: Double
    public var activity: BuildingActivity
    public init(id: String, bundleID: String?, center: Double, width: Double, activity: BuildingActivity) {
        self.id = id; self.bundleID = bundleID; self.center = center
        self.width = width; self.activity = activity
    }
}

public struct CityActor: Sendable {
    public enum State: String, Sendable { case idle, walk, wait, enterBuilding, exitBuilding }
    public var x: Double
    public var destination: Double
    public var state: State = .walk
    public var remaining = 0.0
    public var phase = 0.0
    public var delivery = false
    public var direction: Double = 1
}

/// Deterministic, elapsed-time simulation; bounded and independent of frame rate.
public struct CitySimulation {
    public private(set) var citizens: [CityActor] = []
    public private(set) var vehicles: [CityActor] = []
    private var activeID: String?
    private var width = 1.0
    public init() {}

    public mutating func configure(width: Double, settings: CitySettings, night: Bool) {
        self.width = max(1, width)
        let n = settings.citizensEnabled ? min(settings.citizenDensity.count, max(0, Int(width / 55))) : 0
        let v = settings.trafficEnabled && width >= 90 ? (settings.trafficDensity == .normal ? 2 : min(3, settings.trafficDensity.count)) : 0
        Self.resize(&citizens, count: night ? min(2, n) : n, width: self.width, vehicles: false)
        Self.resize(&vehicles, count: v, width: self.width, vehicles: true)
    }

    private static func resize(_ actors: inout [CityActor], count: Int, width: Double, vehicles: Bool) {
        actors = Array(actors.prefix(count))
        while actors.count < count {
            let index = actors.count
            actors.append(CityActor(x: width * Double(index + 1) / Double(count + 1),
                                    destination: index % 2 == 0 ? width - 12 : 12,
                                    delivery: vehicles && index == 1))
        }
        for i in actors.indices {
            actors[i].x = min(max(actors[i].x, 10), max(10, width - 10))
            actors[i].destination = min(max(actors[i].destination, 10), max(10, width - 10))
        }
    }

    public mutating func activate(_ tile: CityTile?) {
        guard tile?.id != activeID else { return }
        activeID = tile?.id
        guard let tile else { return }
        let target = min(max(tile.center, 10), max(10, width - 10))
        if !citizens.isEmpty {
            citizens[0].destination = target; citizens[0].state = .walk
        }
        if let i = vehicles.firstIndex(where: { $0.delivery }) {
            vehicles[i].destination = target; vehicles[i].state = .walk
        }
    }

    public mutating func step(seconds: Double) {
        let dt = min(0.1, max(0, seconds))
        Self.advance(&citizens, dt: dt, speed: 12, width: width, people: true)
        Self.advance(&vehicles, dt: dt, speed: 27, width: width, people: false)
    }

    private static func advance(_ actors: inout [CityActor], dt: Double, speed: Double, width: Double, people: Bool) {
        for i in actors.indices {
            actors[i].phase += dt
            if actors[i].state != .walk {
                actors[i].remaining -= dt
                if actors[i].remaining <= 0 {
                    if !people && actors[i].state == .idle {
                        actors[i].x = actors[i].x > width / 2 ? 10 : max(10, width - 10)
                        actors[i].destination = actors[i].x > width / 2 ? 10 : max(10, width - 10)
                        actors[i].state = .walk
                        continue
                    }
                    switch actors[i].state {
                    case .enterBuilding: actors[i].state = .idle; actors[i].remaining = 1.5
                    case .idle: actors[i].state = .exitBuilding; actors[i].remaining = 0.4
                    case .exitBuilding: actors[i].state = .wait; actors[i].remaining = 0.5
                    default:
                        actors[i].state = .walk
                        actors[i].destination = actors[i].x > width / 2 ? 10 : max(10, width - 10)
                    }
                }
                continue
            }
            let distance = actors[i].destination - actors[i].x
            actors[i].direction = distance >= 0 ? 1 : -1
            if abs(distance) <= speed * dt {
                actors[i].x = actors[i].destination
                let endpoint = actors[i].x <= 10 || actors[i].x >= width - 10
                actors[i].state = people && i == 0 ? .enterBuilding : (!people && endpoint ? .idle : .wait)
                actors[i].remaining = people ? 0.5 : 1.5
            } else { actors[i].x += actors[i].direction * speed * dt }
        }
    }
}
