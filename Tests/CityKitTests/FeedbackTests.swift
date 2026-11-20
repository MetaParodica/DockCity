import XCTest
import ConfigKit
@testable import CityKit

final class FeedbackTests: XCTestCase {
    private var tile: CityTile { CityTile(id: "/A.app:0", bundleID: "app.a", center: 40, width: 48, activity: .running) }
    func testLaunchEventsExcludeInitialStateUnrelatedAppsAndExpiredEvents() {
        var events = CityLaunchEvents()
        XCTAssertTrue(events.consume(tiles: [tile], now: 0).isEmpty)
        events.launched(bundleID: "app.b", path: nil, now: 1)
        XCTAssertTrue(events.consume(tiles: [tile], now: 1).isEmpty)
        events.launched(bundleID: "app.a", path: nil, now: 1)
        XCTAssertEqual(events.consume(tiles: [tile], now: 1.1), [tile.id])
        XCTAssertTrue(events.consume(tiles: [tile], now: 1.2).isEmpty)
        events.launched(bundleID: "app.a", path: nil, now: 2)
        XCTAssertTrue(events.consume(tiles: [tile], now: 6).isEmpty)
    }
    func testLaunchWaitsForAXTileAndCanMatchPathWithoutBundleID() {
        var events = CityLaunchEvents()
        events.launched(bundleID: nil, path: "/A.app", now: 0)
        XCTAssertTrue(events.consume(tiles: [], now: 0.1).isEmpty)
        XCTAssertEqual(events.consume(tiles: [tile], now: 0.2), [tile.id])
    }
    func testHoverIgnoresSeparatorsAndUsesObservedRects() {
        let app = SystemDockItem(index: 0, role: "AXDockItem", subrole: "AXApplicationDockItem", title: "", axFrame: nil)
        let separator = SystemDockItem(index: 1, role: "AXSeparatorDockItem", subrole: "", title: "", axFrame: nil)
        let frames = [CGRect(x: 0, y: 0, width: 48, height: 48), CGRect(x: 48, y: 0, width: 8, height: 48)]
        XCTAssertEqual(DockHover.itemIndex(at: CGPoint(x: 20, y: 20), items: [app, separator], frames: frames), 0)
        XCTAssertNil(DockHover.itemIndex(at: CGPoint(x: 50, y: 20), items: [app, separator], frames: frames))
        XCTAssertNil(DockHover.itemIndex(at: CGPoint(x: -1, y: 20), items: [app], frames: frames))
    }
    func testShortBadGeometryIsHeldButNeverIndefinitely() {
        var grace = DockSampleGrace()
        XCTAssertFalse(grace.canHold(now: 1)); grace.accept(now: 1)
        XCTAssertTrue(grace.canHold(now: 1.15)); XCTAssertFalse(grace.canHold(now: 1.3))
        grace.reset(); XCTAssertFalse(grace.canHold(now: 1.1))
    }
    func testRevealResumesFromPresentationValueWithoutRestartOnLayoutUpdates() {
        var motion = DockSlide()
        motion.set(visible: true, now: 0, duration: 1)
        XCTAssertEqual(motion.value(at: 0.5), 0.5, accuracy: 1e-9)
        motion.set(visible: true, now: 0.5, duration: 1)
        XCTAssertEqual(motion.value(at: 1), 1, accuracy: 1e-9)
        motion.set(visible: false, now: 1, duration: 1)
        let current = motion.value(at: 1.5)
        motion.set(visible: true, now: 1.5, duration: 1)
        XCTAssertEqual(motion.value(at: 1.5), current, accuracy: 1e-9)
        XCTAssertEqual(motion.value(at: 2.5), 1, accuracy: 1e-9)
    }
    func testDelayedAndReducedMotionReveal() {
        var motion = DockSlide()
        motion.set(visible: true, now: 0, delay: 0.2, duration: 0.5)
        XCTAssertEqual(motion.value(at: 0.1), 0)
        XCTAssertEqual(motion.value(at: 0.7), 1, accuracy: 1e-9)
        motion.set(visible: false, now: 0.8, duration: 0)
        XCTAssertEqual(motion.value(at: 0.8), 0)
        motion.set(visible: true, now: 1, delay: 0.5, duration: 1)
        motion.finish()
        XCTAssertEqual(motion.value(at: 1.1), 1)
    }
    func testStableVariationAndNarrowDockDensity() {
        let a = BuildingVariation(identity: "com.example.editor")
        XCTAssertEqual(a, BuildingVariation(identity: "com.example.editor"))
        let variants = (0..<100).map { BuildingVariation(identity: "app.\($0)") }
        XCTAssertGreaterThan(Set(variants.map(\.color)).count, 4)
        XCTAssertGreaterThan(Set(variants.map(\.height)).count, 10)
        var simulation = CitySimulation()
        simulation.configure(width: 110, settings: CitySettings(), night: false)
        XCTAssertLessThanOrEqual(simulation.citizens.count, 2)
        XCTAssertLessThanOrEqual(simulation.vehicles.count, 1)
    }
    func testBackgroundDefaultAndRoundTrip() throws {
        XCTAssertEqual(try JSONDecoder().decode(CitySettings.self, from: Data("{}".utf8)).background, .sky)
        var settings = CitySettings(); settings.background = .transparent
        XCTAssertEqual(try JSONDecoder().decode(CitySettings.self, from: JSONEncoder().encode(settings)), settings)
    }
}
