import XCTest
import ConfigKit
@testable import CityKit
#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class TrackedCityLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 700)
    private func item(_ rect: CGRect, index: Int = 0) -> SystemDockItem {
        SystemDockItem(index: index, role: "AXDockItem", subrole: "AXApplicationDockItem", title: "App",
                       axFrame: SystemDockGeometry.cocoaFrame(axFrame: rect, primaryMaxY: 700))
    }
    func testBottomTracksMagnifiedCentersAndLeavesIconsUntouched() throws {
        let a = CGRect(x: 100, y: 8, width: 50, height: 50)
        let b = CGRect(x: 175, y: 8, width: 80, height: 80)
        let layout = try XCTUnwrap(TrackedCityLayout.make(items: [item(a), item(b, index: 1)], primaryMaxY: 700,
            screens: [screen], orientation: .bottom, height: 90))
        XCTAssertEqual(layout.frame, CGRect(x: 100, y: 91, width: 155, height: 90))
        XCTAssertEqual(layout.center(of: a), 25)
        XCTAssertEqual(layout.center(of: b), 115)
        XCTAssertFalse(layout.frame.intersects(a)); XCTAssertFalse(layout.frame.intersects(b))
    }
    func testVerticalRotationKeepsCentersAligned() throws {
        for orientation in [SystemDockOrientation.left, .right] {
            let x: CGFloat = orientation == .left ? 0 : 950
            let a = CGRect(x: x, y: 100, width: 50, height: 50)
            let b = CGRect(x: x, y: 200, width: 50, height: 50)
            let layout = try XCTUnwrap(TrackedCityLayout.make(items: [item(a), item(b, index: 1)], primaryMaxY: 700,
                screens: [screen], orientation: orientation, height: 90))
            XCTAssertEqual(layout.length, 150); XCTAssertEqual(layout.depth, 90)
            XCTAssertEqual(layout.center(of: a), orientation == .left ? 125 : 25)
            XCTAssertEqual(layout.center(of: b), orientation == .left ? 25 : 125)
            XCTAssertTrue(screen.contains(layout.frame)); XCTAssertFalse(layout.frame.intersects(a))
        }
    }
    func testHiddenPartiallyHiddenAndInvalidGeometryHideCity() {
        XCTAssertFalse(TrackedCityLayout.dockWindowIsVisible(CGRect(x: 100, y: 699, width: 300, height: 60),
            primaryMaxY: 700, screens: [screen], orientation: .bottom))
        XCTAssertTrue(TrackedCityLayout.dockWindowIsVisible(CGRect(x: 100, y: 640, width: 300, height: 60),
            primaryMaxY: 700, screens: [screen], orientation: .bottom))
        for items in [[], [item(CGRect(x: 100, y: -55, width: 50, height: 50))],
                      [item(CGRect(x: 100, y: -5, width: 50, height: 50))],
                      [item(CGRect(x: 100, y: 8, width: 50, height: 50)), item(CGRect(x: 155, y: -5, width: 50, height: 50))],
                      [SystemDockItem(index: 0, role: "AXDockItem", subrole: "", title: "", axFrame: nil)]] {
            XCTAssertNil(TrackedCityLayout.make(items: items, primaryMaxY: 700, screens: [screen], orientation: .bottom, height: 90))
        }
    }
    func testNegativeDisplayCoordinatesAndMissingItemFramesArePreserved() throws {
        let a = item(CGRect(x: -900, y: 10, width: 60, height: 60))
        let unknown = SystemDockItem(index: 1, role: "AXSeparator", subrole: "", title: "", axFrame: nil)
        let display = CGRect(x: -1000, y: 0, width: 1000, height: 700)
        let layout = try XCTUnwrap(TrackedCityLayout.make(items: [a, unknown], primaryMaxY: 700,
            screens: [screen, display], orientation: .bottom, height: 90))
        XCTAssertEqual(layout.frame.minX, -900); XCTAssertEqual(layout.items, [a])
        XCTAssertEqual(layout.center(of: layout.itemFrames[0]), 30)
    }
    func testCityClipsToScreenAndRefusesNoRemainingSpace() throws {
        let a = item(CGRect(x: 100, y: 650, width: 50, height: 20))
        let layout = try XCTUnwrap(TrackedCityLayout.make(items: [a], primaryMaxY: 700, screens: [screen], orientation: .bottom, height: 90))
        XCTAssertEqual(layout.depth, 27)
        XCTAssertNil(TrackedCityLayout.make(items: [item(CGRect(x: 100, y: 650, width: 50, height: 50))], primaryMaxY: 700,
            screens: [screen], orientation: .bottom, height: 90))
        XCTAssertNil(TrackedCityLayout.make(items: [a], primaryMaxY: 700, screens: [screen], orientation: .bottom, height: -.infinity))
    }
    func testApplicationURLSurvivesJSONAndLegacyObservationsStillDecode() throws {
        var app = item(CGRect(x: 100, y: 8, width: 50, height: 50))
        app.applicationURL = URL(fileURLWithPath: "/Applications/My App.app")
        XCTAssertEqual(try JSONDecoder().decode(SystemDockItem.self, from: JSONEncoder().encode(app)), app)
        let legacy = Data(#"{"index":0,"role":"AXDockItem","subrole":"AXApplicationDockItem","title":"App"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SystemDockItem.self, from: legacy).applicationURL)
    }
    func testActiveAppReorderingUpdatesDeliveryDestinationWithoutTeleporting() {
        var simulation = CitySimulation()
        simulation.configure(width: 500, settings: CitySettings(), night: false)
        simulation.activate(CityTile(id: "same-app", bundleID: nil, center: 150, width: 50, activity: .active))
        let x = simulation.citizens[0].x
        simulation.activate(CityTile(id: "same-app", bundleID: nil, center: 350, width: 50, activity: .active))
        XCTAssertEqual(simulation.citizens[0].destination, 350)
        XCTAssertEqual(simulation.vehicles[1].destination, 350)
        XCTAssertEqual(simulation.citizens[0].x, x)
        var settings = CitySettings(); settings.citizensEnabled = false; settings.trafficEnabled = false
        simulation.configure(width: 500, settings: settings, night: false)
        simulation.activate(CityTile(id: "same-app", bundleID: nil, center: 350, width: 50, activity: .active))
        simulation.configure(width: 500, settings: CitySettings(), night: false)
        simulation.activate(CityTile(id: "same-app", bundleID: nil, center: 350, width: 50, activity: .active))
        XCTAssertEqual(simulation.citizens[0].destination, 350)
        XCTAssertEqual(simulation.vehicles[1].destination, 350)
    }
}
