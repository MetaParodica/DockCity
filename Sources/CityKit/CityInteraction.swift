import Foundation

public struct CityLaunchEvents {
    private struct Entry { let bundleID: String?; let path: String?; let time: Double }
    private var pending: [Entry] = []
    public init() {}
    public mutating func launched(bundleID: String?, path: String?, now: Double) {
        guard bundleID != nil || path != nil, now.isFinite else { return }
        pending.append(Entry(bundleID: bundleID, path: path, time: now))
        pending = Array(pending.suffix(128))
    }
    public mutating func consume(tiles: [CityTile], now: Double) -> Set<String> {
        var result = Set<String>()
        pending = pending.filter { event in
            guard now - event.time <= 3, now >= event.time else { return false }
            let matches = tiles.filter { tile in
                (event.bundleID != nil && tile.bundleID == event.bundleID)
                    || event.path.map { tile.id.hasPrefix($0 + ":") } == true
            }
            result.formUnion(matches.map(\.id)); return matches.isEmpty
        }
        return result
    }
}

public enum DockHover {
    public static func itemIndex(at point: CGPoint, items: [SystemDockItem], frames: [CGRect]) -> Int? {
        zip(items, frames).filter { $0.0.kind == .application && $0.1.contains(point) }
            .min { a, b in
                hypot(a.1.midX - point.x, a.1.midY - point.y) < hypot(b.1.midX - point.x, b.1.midY - point.y)
            }?.0.index
    }
}

public struct BuildingVariation: Equatable {
    public let width: Double
    public let height: Double
    public let roof: Int
    public let color: String
    public init(identity: String) {
        var hash: UInt64 = 14695981039346656037
        for byte in identity.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        hash ^= hash >> 33; hash = hash &* 0xff51afd7ed558ccd
        hash ^= hash >> 33; hash = hash &* 0xc4ceb9fe1a85ec53; hash ^= hash >> 33
        width = 0.78 + Double(hash % 24) / 100
        height = 0.72 + Double((hash >> 8) % 29) / 100
        roof = Int((hash >> 16) % 4)
        color = ["#B7978C", "#71A8B7", "#C19A6B", "#BD7E8D", "#9BAA86", "#7F8BA2"][Int((hash >> 24) % 6)]
    }
}
