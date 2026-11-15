import XCTest
import ConfigKit
@testable import SnowCore

final class SnowSimulationTests: XCTestCase {
    private func surface(_ id: UInt64 = 1, x: Double = 20, y: Double = 100, width: Double = 200,
                         height: Double = 120, kind: SnowSurface.Kind = .window) -> SnowSurface {
        SnowSurface(id: id, frame: SnowRect(x: x, y: y, width: width, height: height), kind: kind)
    }
    private func prepared() -> SnowSimulation {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([surface()], elapsed: 0.1)
        XCTAssertTrue(s.deposit(on: 1, x: 80, amount: 48)); return s
    }
    func testSnowfallActuallyAccumulatesOnWindow() {
        let s = SnowSimulation(width: 500, height: 500, seed: 42)
        s.updateSurfaces([surface(x: 0, y: 80, width: 500)], elapsed: 0.1)
        for _ in 0..<1800 { s.step(seconds: 1 / 60) }
        XCTAssertGreaterThan(s.piles[1]!.heights.reduce(0, +), 0)
        XCTAssertFalse(s.particles.isEmpty)
    }
    func testSweptCollisionCannotTunnelThroughWindowAtLowFrameRate() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([surface(y: 100)], elapsed: 0.1)
        s.addParticle(SnowParticle(x: 80, y: 95, vy: 400, debris: true))
        s.step(seconds: 1 / 15)
        XCTAssertGreaterThan(s.piles[1]!.height(at: 80), 0)
        XCTAssertFalse(s.particles.contains { $0.debris })
    }
    func testFrontWindowOccludesRearBankAndCatchesSnowFirst() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([surface(1, y: 70), surface(2, y: 100)], elapsed: 0.1)
        XCTAssertFalse(s.deposit(on: 2, x: 80, amount: 30))
        s.addParticle(SnowParticle(x: 80, y: 60, vy: 200)); s.step(seconds: 0.1)
        // Sway may move contact into the adjacent column; assert which bank caught it.
        XCTAssertGreaterThan(s.piles[1]!.heights.reduce(0, +), 0)
        XCTAssertEqual(s.piles[2]!.heights.reduce(0, +), 0)
    }
    func testUncoveredPartOfRearWindowStillAccumulates() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([surface(1, x: 20, y: 70, width: 80), surface(2, x: 20, y: 100, width: 200)], elapsed: 0.1)
        XCTAssertFalse(s.deposit(on: 2, x: 60, amount: 20))
        XCTAssertTrue(s.deposit(on: 2, x: 150, amount: 20))
    }
    func testSlowWindowMotionCarriesBankWithoutShedding() {
        let s = prepared(); let heights = s.piles[1]!.heights
        s.updateSurfaces([surface(x: 25)], elapsed: 0.1)
        XCTAssertEqual(s.piles[1]!.heights, heights)
        XCTAssertTrue(s.particles.isEmpty)
        XCTAssertGreaterThan(s.piles[1]!.height(at: 85), 0)
    }
    func testFastWindowMotionThrowsSnowWithMomentum() {
        let s = prepared()
        s.updateSurfaces([surface(x: 100)], elapsed: 0.1)
        XCTAssertEqual(s.piles[1]!.heights.reduce(0, +), 0)
        let debris = s.particles.filter(\.debris)
        XCTAssertFalse(debris.isEmpty); XCTAssertTrue(debris.allSatisfy { $0.vx > 0 })
    }
    func testResizeAndClosureReleaseSnow() {
        for close in [false, true] {
            let s = prepared()
            s.updateSurfaces(close ? [] : [surface(width: 120)], elapsed: 0.1)
            XCTAssertTrue(s.particles.contains(where: \.debris))
            XCTAssertEqual(s.piles[1]?.heights.reduce(0, +) ?? 0, 0)
        }
    }
    func testTeleportDoesNotFlingSnowAcrossSpaces() {
        let s = prepared()
        s.updateSurfaces([surface(x: 400)], elapsed: 0.1)
        XCTAssertEqual(s.piles[1]!.heights.reduce(0, +), 0)
        XCTAssertTrue(s.particles.isEmpty)
    }
    func testDetachedSnowFallsUnderGravityAndCanLandOnLowerWindow() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([surface(2, y: 250)], elapsed: 0.1)
        s.addParticle(SnowParticle(x: 80, y: 100, vy: 0, debris: true))
        s.step(seconds: 0.1)
        XCTAssertGreaterThan(s.particles[0].vy, 0); XCTAssertGreaterThan(s.particles[0].y, 100)
        for _ in 0..<150 { s.step(seconds: 1 / 60) }
        XCTAssertGreaterThan(s.piles[2]!.height(at: 80), 0)
    }
    func testDockUsesObservedSurfaceAndMagnificationDoesNotThrowSnow() {
        let s = SnowSimulation(width: 500, height: 500)
        s.updateSurfaces([surface(UInt64.max, y: 450, kind: .dock)], elapsed: 0.1)
        XCTAssertTrue(s.deposit(on: UInt64.max, x: 80, amount: 30))
        s.updateSurfaces([surface(UInt64.max, x: 10, y: 430, width: 240, kind: .dock)], elapsed: 0.1)
        XCTAssertGreaterThan(s.piles[UInt64.max]!.heights.reduce(0, +), 0)
        XCTAssertTrue(s.particles.isEmpty)
    }
    func testAccumulationTogglesRemainIndependent() {
        let s = SnowSimulation(width: 500, height: 500)
        var settings = SnowSettings(); settings.accumulateOnWindows = false
        s.configure(settings)
        s.updateSurfaces([surface(), surface(2, y: 450, kind: .dock)], elapsed: 0.1)
        XCTAssertNil(s.piles[1]); XCTAssertNotNil(s.piles[2])
        settings.accumulateOnWindows = true; settings.accumulateOnDock = false; s.configure(settings)
        s.updateSurfaces(s.surfaces, elapsed: 0.1)
        XCTAssertNotNil(s.piles[1]); XCTAssertNil(s.piles[2])
    }
    func testReduceMotionPreservesBanksAndStopsParticles() {
        let s = prepared(); let pile = s.piles[1]!.heights
        s.addParticle(SnowParticle(x: 40, y: 20))
        var settings = SnowSettings(); settings.reduceMotion = true; s.configure(settings)
        s.step(seconds: 1)
        XCTAssertTrue(s.particles.isEmpty); XCTAssertEqual(s.piles[1]!.heights, pile)
    }
    func testPauseAndClearRemoveSnowWithoutChangingSystemGeometry() {
        let s = prepared(); s.clear()
        XCTAssertTrue(s.piles.isEmpty); XCTAssertTrue(s.particles.isEmpty)
        s.updateSurfaces([surface()], elapsed: 0.1)
        var settings = SnowSettings(); settings.enabled = false; s.configure(settings)
        s.step(seconds: 10)
        XCTAssertTrue(s.particles.isEmpty); XCTAssertTrue(s.piles.isEmpty)
    }
    func testDepthAndStorageRemainBoundedDuringLongSnowfall() {
        let s = SnowSimulation(width: 500, height: 500)
        var settings = SnowSettings(); settings.maximumDepth = 4; settings.intensity = .flurry; s.configure(settings)
        s.updateSurfaces([surface(x: 0, y: 70, width: 500)], elapsed: 0.1)
        for _ in 0..<5000 { s.step(seconds: 1 / 30) }
        XCTAssertTrue(s.piles[1]!.heights.allSatisfy { $0 >= 0 && $0 <= 4 && $0.isFinite })
        XCTAssertLessThanOrEqual(s.particles.count, SnowSimulation.maximumParticles)
        XCTAssertLessThanOrEqual(s.piles[1]!.heights.count, SnowSimulation.maximumCellsPerSurface)
    }
    func testFixedStepIsFrameRateIndependent() {
        let a = SnowSimulation(width: 500, height: 500, seed: 19)
        let b = SnowSimulation(width: 500, height: 500, seed: 19)
        for _ in 0..<300 { a.step(seconds: 1 / 30) }
        for _ in 0..<600 { b.step(seconds: 1 / 60) }
        XCTAssertEqual(a.particles, b.particles)
    }
    func testInvalidNumbersAndDuplicateHugeInputCannotCrashOrAllocateUnboundedly() {
        let s = SnowSimulation(width: .infinity, height: .nan)
        XCTAssertEqual(s.width, 1); XCTAssertEqual(s.height, 1)
        var input = (0..<1000).map { surface(UInt64($0), width: 50_000) }
        input.insert(surface(2, x: .nan), at: 0); input.append(surface(2))
        s.updateSurfaces(input, elapsed: .nan)
        s.step(seconds: .infinity); s.step(seconds: .nan); s.step(seconds: -1)
        s.addParticle(SnowParticle(x: .nan, y: 2))
        XCTAssertLessThanOrEqual(s.piles.count, SnowScene.maximumSurfaces)
        XCTAssertTrue(s.particles.isEmpty)
        XCTAssertFalse(s.deposit(on: 1, x: .infinity, amount: .nan))
    }
    func testDetachedParticlesAndGeometryStayFiniteUnderMotionChurn() {
        let s = prepared()
        for i in 0..<1000 {
            s.updateSurfaces([surface(x: Double(i % 4) * 65, width: Double(80 + i % 120))], elapsed: i % 2 == 0 ? 0 : 0.02)
            _ = s.deposit(on: 1, x: s.surfaces[0].frame.x + 30, amount: 6)
            s.step(seconds: 1 / 30)
        }
        XCTAssertTrue(s.particles.allSatisfy { [$0.x, $0.y, $0.vx, $0.vy].allSatisfy(\.isFinite) })
        XCTAssertLessThanOrEqual(s.particles.count, SnowSimulation.maximumParticles)
    }
}
