import Foundation
import ConfigKit

public struct SnowParticle: Equatable, Sendable {
    public var x: Double, y: Double, vx: Double, vy: Double, radius: Double
    public var debris: Bool
    public var phase = 0.0
    public init(x: Double, y: Double, vx: Double = 0, vy: Double = 25, radius: Double = 1.2, debris: Bool = false) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.radius = radius; self.debris = debris
    }
}

public struct SnowPile: Sendable {
    public var surface: SnowSurface
    public var heights: [Double]
    public var cellWidth: Double { surface.frame.width / Double(heights.count) }
    public func height(at x: Double) -> Double {
        let local = x - surface.frame.x
        guard local >= 0, local < surface.frame.width else { return 0 }
        return heights[min(heights.count - 1, Int(local / cellWidth))]
    }
}

/// Bounded, headless height-column / falling-particle solver.
/// Design references: SnowDesk's column piles, fling threshold and occlusion;
/// see THIRD_PARTY_NOTICES.md. This implementation has no Cocoa dependencies.
public final class SnowSimulation {
    public static let maximumParticles = 1200
    public static let maximumCellsPerSurface = 256
    public private(set) var particles: [SnowParticle] = []
    public private(set) var piles: [UInt64: SnowPile] = [:]
    public private(set) var surfaces: [SnowSurface] = []
    public let width: Double, height: Double
    public private(set) var settings = SnowSettings()
    private var randomState: UInt64
    private var accumulator = 0.0
    private var emission = 0.0

    public init(width: Double, height: Double, seed: UInt64 = 0xD0CC17) {
        self.width = width.isFinite ? min(32_768, max(1, width)) : 1
        self.height = height.isFinite ? min(32_768, max(1, height)) : 1
        randomState = max(1, seed)
    }
    public func configure(_ settings: SnowSettings) {
        self.settings = settings
        self.settings.maximumDepth = settings.maximumDepth.isFinite ? min(30, max(2, settings.maximumDepth)) : 16
        if !settings.enabled { clear(); return }
        if settings.reduceMotion { particles.removeAll(); emission = 0; accumulator = 0 }
        for id in Array(piles.keys) {
            guard var pile = piles[id] else { continue }
            if !collects(pile.surface) { piles[id] = nil; continue }
            pile.heights = pile.heights.map { min($0, self.settings.maximumDepth) }; piles[id] = pile
        }
    }
    public func clear() {
        particles.removeAll(keepingCapacity: true); piles.removeAll(keepingCapacity: true)
        surfaces.removeAll(keepingCapacity: true); emission = 0; accumulator = 0
    }
    private func collects(_ surface: SnowSurface) -> Bool {
        surface.kind == .dock ? settings.accumulateOnDock : settings.accumulateOnWindows
    }
    private func random() -> Double {
        randomState ^= randomState << 13; randomState ^= randomState >> 7; randomState ^= randomState << 17
        return Double(randomState & 0x1F_FFFF_FFFF_FFFF) / Double(0x20_0000_0000_0000)
    }
    public func addParticle(_ particle: SnowParticle) {
        guard particles.count < Self.maximumParticles,
              [particle.x, particle.y, particle.vx, particle.vy, particle.radius, particle.phase].allSatisfy({ $0.isFinite && abs($0) < 100_000 }),
              particle.radius > 0, particle.radius <= 8 else { return }
        particles.append(particle)
    }
    /// Input is front-to-back; vanished supports release their snow. The runtime
    /// explicitly clears on Spaces/display transitions rather than treating them as throws.
    public func updateSurfaces(_ input: [SnowSurface], elapsed: Double) {
        let next = SnowScene.validated(input)
        let ids = Set(next.map(\.id))
        let dt = elapsed.isFinite ? max(1 / 120, min(0.5, elapsed)) : 0.1
        for id in Array(piles.keys) where !ids.contains(id) {
            if let pile = piles.removeValue(forKey: id), !settings.reduceMotion { release(pile, vx: 0, vy: 0) }
        }
        surfaces = next
        guard settings.enabled else { return }
        for surface in next where collects(surface) {
            let count = max(2, min(Self.maximumCellsPerSurface, Int(ceil(surface.frame.width / 4))))
            guard var pile = piles[surface.id] else {
                piles[surface.id] = SnowPile(surface: surface, heights: Array(repeating: 0, count: count)); continue
            }
            let old = pile.surface.frame, new = surface.frame
            let dx = new.x - old.x, dy = new.y - old.y
            let resized = abs(new.width - old.width) > 1 || abs(new.height - old.height) > 1
            let teleport = abs(dx) > width * 0.7 || abs(dy) > height * 0.7
            let speed = hypot(dx, dy) / dt
            if teleport {
                pile.heights = Array(repeating: 0, count: count)
            } else if surface.kind == .window && (resized || speed > 350) {
                if !settings.reduceMotion {
                    release(pile, vx: min(900, max(-900, dx / dt * 0.6)), vy: min(500, max(-100, dy / dt * 0.4)))
                }
                pile.heights = Array(repeating: 0, count: count)
            } else if count != pile.heights.count {
                let previous = pile.heights
                pile.heights = (0..<count).map { previous[min(previous.count - 1, Int(Double($0) * Double(previous.count) / Double(count)))] }
            }
            pile.surface = surface; piles[surface.id] = pile
        }
    }
    /// Deposits a bounded amount of area, used by collision handling and previews.
    @discardableResult public func deposit(on id: UInt64, x: Double, amount: Double) -> Bool {
        guard settings.enabled, amount.isFinite, amount > 0, x.isFinite,
              var pile = piles[id], let index = surfaces.firstIndex(where: { $0.id == id }),
              x >= pile.surface.frame.x, x < pile.surface.frame.right,
              !SnowScene.covered(x: x, y: pile.surface.frame.y - 0.5, in: surfaces, before: index) else { return false }
        let cell = min(pile.heights.count - 1, Int((x - pile.surface.frame.x) / pile.cellWidth))
        let distance = min(x - pile.surface.frame.x, pile.surface.frame.right - x)
        let taper = min(1, max(0, distance / 8))
        let limit = settings.maximumDepth * taper
        guard pile.heights[cell] < limit else { return false }
        pile.heights[cell] = min(limit, pile.heights[cell] + min(1000, amount) / pile.cellWidth)
        piles[id] = pile; return true
    }
    private func release(_ pile: SnowPile, vx: Double, vy: Double) {
        for i in pile.heights.indices where pile.heights[i] > 0.15 {
            let x = pile.surface.frame.x + (Double(i) + 0.5) * pile.cellWidth
            let y = pile.surface.frame.y - pile.heights[i] / 2 - 2
            // Don't create material from a snowbank hidden behind a front window.
            if let index = surfaces.firstIndex(where: { $0.id == pile.surface.id }),
               SnowScene.covered(x: x, y: y, in: surfaces, before: index) { continue }
            addParticle(SnowParticle(x: x, y: y, vx: vx + settings.fallVector.x * 0.5 + (random() - 0.5) * 30,
                vy: vy + settings.fallVector.y * 0.5,
                radius: min(3, max(1.2, sqrt(pile.heights[i]) * 0.6)), debris: true))
        }
    }
    public func step(seconds: Double) {
        guard settings.enabled, !settings.reduceMotion, seconds.isFinite, seconds > 0 else { return }
        accumulator += min(0.25, seconds)
        let dt = 1.0 / 60
        while accumulator + 1e-10 >= dt { advance(dt); accumulator = max(0, accumulator - dt) }
    }
    private func advance(_ dt: Double) {
        let vector = settings.fallVector, speed = vector.speed
        let span = speed > 0.001 ? (width * abs(vector.y) + height * abs(vector.x)) / speed : 0
        emission += settings.intensity.flakesPerSecond * min(3, span / 1440) * dt
        while emission >= 1 {
            emission -= 1
            let lateralFlux = abs(vector.x) * height
            let totalFlux = lateralFlux + abs(vector.y) * width
            let fromSide = totalFlux > 0 && random() * totalFlux < lateralFlux
            let radius = 0.8 + random()
            var particle = SnowParticle(
                x: fromSide ? (vector.x >= 0 ? -4 : width + 4) : random() * width,
                y: fromSide ? random() * height : (vector.y >= 0 ? -4 : height + 4),
                vx: vector.x * (0.7 + radius * 0.2), vy: vector.y * (0.7 + radius * 0.2), radius: radius)
            particle.phase = random() * .pi * 2
            addParticle(particle)
        }
        var survivors: [SnowParticle] = []; survivors.reserveCapacity(particles.count)
        for var particle in particles {
            let oldX = particle.x, oldY = particle.y
            if particle.debris {
                // Wind steers released material; gravity always remains downward.
                particle.vy = min(500, particle.vy + (150 + vector.y * 0.3) * dt)
                particle.vx += (vector.x * 0.6 - particle.vx) * (1 - exp(-0.6 * dt))
            } else {
                particle.phase += dt * 1.6
                let sway = sin(particle.phase) * min(3, speed * 0.08)
                let factor = 0.7 + particle.radius * 0.2
                let targetX = vector.x * factor + (speed > 0.001 ? -vector.y / speed * sway : 0)
                let targetY = vector.y * factor + (speed > 0.001 ? vector.x / speed * sway : 0)
                let follow = 1 - exp(-4 * dt)
                particle.vx += (targetX - particle.vx) * follow
                particle.vy += (targetY - particle.vy) * follow
            }
            particle.x += particle.vx * dt; particle.y += particle.vy * dt
            guard particle.y > -16, particle.y < height + 16, particle.x > -16, particle.x < width + 16 else { continue }
            var hit: (UInt64, Double, Double)?
            for (index, surface) in surfaces.enumerated() {
                guard let pile = piles[surface.id] else { continue }
                let top = surface.frame.y - pile.height(at: particle.x) - particle.radius
                guard oldY <= top, particle.y >= top, particle.y > oldY else { continue }
                let t = (top - oldY) / (particle.y - oldY)
                let x = oldX + (particle.x - oldX) * t
                guard x >= surface.frame.x, x < surface.frame.right,
                      !SnowScene.covered(x: x, y: top, in: surfaces, before: index) else { continue }
                if hit == nil || t < hit!.2 { hit = (surface.id, x, t) }
            }
            if let (id, x, _) = hit {
                _ = deposit(on: id, x: x, amount: particle.debris ? 6 : 2.5)
                // Even saturated banks catch ambient flakes instead of tunneling through windows.
                continue
            }
            survivors.append(particle)
        }
        particles = survivors
    }
}
