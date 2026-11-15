import XCTest
import ConfigKit
@testable import SnowCore

final class SnowDirectionTests: XCTestCase {
    func testBothWindowAndDockCollectSnowInSameScene() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([
            SnowSurface(id: UInt64.max, frame: SnowRect(x: 0, y: 440, width: 500, height: 60), kind: .dock),
            SnowSurface(id: 1, frame: SnowRect(x: 40, y: 100, width: 180, height: 150))], elapsed: 0.1)
        s.addParticle(SnowParticle(x: 80, y: 90, vy: 200))
        s.addParticle(SnowParticle(x: 350, y: 430, vy: 200))
        s.step(seconds: 0.1)
        XCTAssertGreaterThan(s.piles[1]!.heights.reduce(0, +), 0)
        XCTAssertGreaterThan(s.piles[UInt64.max]!.heights.reduce(0, +), 0)
    }
    func testSnowReleasedByWindowCanAccumulateOnDock() {
        let s = SnowSimulation(width: 500, height: 500)
        let dock = SnowSurface(id: UInt64.max, frame: SnowRect(x: 0, y: 440, width: 500, height: 60), kind: .dock)
        s.updateSurfaces([dock, SnowSurface(id: 1, frame: SnowRect(x: 20, y: 100, width: 200, height: 120))], elapsed: 0.1)
        XCTAssertTrue(s.deposit(on: 1, x: 80, amount: 50))
        s.updateSurfaces([dock], elapsed: 0.1)
        XCTAssertTrue(s.particles.contains(where: \.debris))
        for _ in 0..<180 { s.step(seconds: 1 / 60) }
        XCTAssertGreaterThan(s.piles[UInt64.max]!.heights.reduce(0, +), 0)
    }
    func testAllTravelDirectionsEnterFromCorrectBoundary() {
        for vector in [SnowFallVector(x: 100, y: 0), SnowFallVector(x: -100, y: 0),
                       SnowFallVector(x: 0, y: 100), SnowFallVector(x: 0, y: -100)] {
            let s = SnowSimulation(width: 500, height: 500, seed: 17)
            var settings = SnowSettings(); settings.intensity = .flurry; settings.fallVector = vector; s.configure(settings)
            for _ in 0..<30 { s.step(seconds: 1 / 60) }
            XCTAssertFalse(s.particles.isEmpty)
            for p in s.particles {
                if vector.x > 0 { XCTAssertGreaterThan(p.vx, 0); XCTAssertLessThan(p.x, 60) }
                if vector.x < 0 { XCTAssertLessThan(p.vx, 0); XCTAssertGreaterThan(p.x, 440) }
                if vector.y > 0 { XCTAssertGreaterThan(p.vy, 0); XCTAssertLessThan(p.y, 60) }
                if vector.y < 0 { XCTAssertLessThan(p.vy, 0); XCTAssertGreaterThan(p.y, 440) }
            }
        }
    }
    func testDiagonalWindReachesWindowAndDock() {
        let s = SnowSimulation(width: 500, height: 500, seed: 42)
        var settings = SnowSettings(); settings.fallVector = SnowFallVector(x: 20, y: 55); settings.intensity = .flurry
        s.configure(settings)
        s.updateSurfaces([
            SnowSurface(id: UInt64.max, frame: SnowRect(x: 0, y: 440, width: 500, height: 60), kind: .dock),
            SnowSurface(id: 1, frame: SnowRect(x: 80, y: 100, width: 200, height: 120))], elapsed: 0.1)
        for _ in 0..<2400 { s.step(seconds: 1 / 60) }
        XCTAssertGreaterThan(s.piles[1]!.heights.reduce(0, +), 0)
        XCTAssertGreaterThan(s.piles[UInt64.max]!.heights.reduce(0, +), 0)
    }
    func testVectorChangesSteerExistingParticlesAndGravityStillActsOnDebris() {
        let s = SnowSimulation(width: 500, height: 500)
        s.addParticle(SnowParticle(x: 250, y: 200, vx: 0, vy: 0))
        s.addParticle(SnowParticle(x: 250, y: 200, vx: 0, vy: 0, debris: true))
        var settings = SnowSettings(); settings.fallVector = SnowFallVector(x: 100, y: -50); s.configure(settings)
        s.step(seconds: 0.25)
        XCTAssertGreaterThan(s.particles[0].vx, 0); XCTAssertLessThan(s.particles[0].vy, 0)
        XCTAssertGreaterThan(s.particles[1].vx, 0); XCTAssertGreaterThan(s.particles[1].vy, 0)
    }
    func testZeroVectorStopsSpawningAndDoesNotRemoveSettledBanks() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([SnowSurface(id: 1, frame: SnowRect(x: 20, y: 100, width: 200, height: 120))], elapsed: 0.1)
        XCTAssertTrue(s.deposit(on: 1, x: 80, amount: 30))
        let heights = s.piles[1]!.heights
        var settings = SnowSettings(); settings.fallVector = SnowFallVector(x: 0, y: 0); s.configure(settings)
        for _ in 0..<600 { s.step(seconds: 1 / 60) }
        XCTAssertTrue(s.particles.isEmpty); XCTAssertEqual(s.piles[1]!.heights, heights)
    }
    func testUpwardFlowLeavesTopBanksUnchangedAndExitsAtTop() {
        let s = SnowSimulation(width: 500, height: 500)
        var settings = SnowSettings(); settings.fallVector = SnowFallVector(x: 0, y: -150); s.configure(settings)
        s.updateSurfaces([SnowSurface(id: 1, frame: SnowRect(x: 20, y: 200, width: 450, height: 120))], elapsed: 0.1)
        for _ in 0..<600 { s.step(seconds: 1 / 60) }
        XCTAssertEqual(s.piles[1]!.heights.reduce(0, +), 0)
        XCTAssertTrue(s.particles.allSatisfy { $0.y > -16 })
    }
    func testDirectionalMotionRemainsIndependentOfFrameRate() {
        let a = SnowSimulation(width: 500, height: 500, seed: 11)
        let b = SnowSimulation(width: 500, height: 500, seed: 11)
        var settings = SnowSettings(); settings.fallVector = SnowFallVector(x: -60, y: 40)
        a.configure(settings); b.configure(settings)
        for _ in 0..<300 { a.step(seconds: 1 / 30) }
        for _ in 0..<600 { b.step(seconds: 1 / 60) }
        XCTAssertEqual(a.particles, b.particles)
    }
}
