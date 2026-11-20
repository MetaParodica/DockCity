import XCTest
import AppKit
import ConfigKit
import CityKit
@testable import DockKit

final class CityFeedbackTests: XCTestCase {
    func testLaunchAndHoverAreLocalAndSurviveGeometryRefresh() throws {
        let scene = CityScene(); scene.root.bounds = CGRect(x: 0, y: 0, width: 200, height: 90)
        let tiles = [CityTile(id: "a", bundleID: "app.a", center: 45, width: 50, activity: .running),
                     CityTile(id: "b", bundleID: "app.b", center: 125, width: 50, activity: .running)]
        scene.configure(tiles: tiles, settings: CitySettings(), night: false, scale: 1)
        let buildings = try XCTUnwrap(scene.root.sublayers?.first { $0.name == "buildings" })
        let a = try XCTUnwrap(buildings.sublayers?.first { $0.name == "a" })
        let b = try XCTUnwrap(buildings.sublayers?.first { $0.name == "b" })
        XCTAssertNil(a.animation(forKey: "launch"))
        scene.launch(tileIDs: ["a"]); scene.hover(tileID: "a")
        XCTAssertNotNil(a.animation(forKey: "launch")); XCTAssertNotNil(a.animation(forKey: "hover"))
        XCTAssertNil(b.animation(forKey: "launch")); XCTAssertNil(b.animation(forKey: "hover"))
        scene.root.bounds.size.width = 205
        scene.configure(tiles: tiles, settings: CitySettings(), night: false, scale: 1)
        XCTAssertTrue(buildings.sublayers?.first === a)
        XCTAssertNotNil(a.animation(forKey: "launch"))
        XCTAssertNil(scene.root.animation(forKey: "theme"))
        scene.hover(tileID: nil)
        XCTAssertNil(a.animation(forKey: "hover")); XCTAssertNotNil(a.animation(forKey: "hoverReturn"))
        var settings = CitySettings(); settings.reduceMotion = true
        scene.configure(tiles: tiles, settings: settings, night: false, scale: 1)
        XCTAssertNil(a.animation(forKey: "launch")); XCTAssertNil(a.animation(forKey: "hover"))
        XCTAssertNil(a.animation(forKey: "hoverReturn"))
    }
    func testAllSkinsKeepDistinctNightFacadesAndBackgroundCanBeHidden() throws {
        let scene = CityScene(); scene.root.bounds = CGRect(x: 0, y: 0, width: 1000, height: 90)
        var settings = CitySettings()
        let tiles = BuildingStyle.allCases.enumerated().map { i, style -> CityTile in
            let id = style.rawValue; settings.buildings[id] = BuildingOverride(style: style)
            return CityTile(id: id, bundleID: id, center: Double(40 + i * 80), width: 60, activity: .running)
        }
        scene.configure(tiles: tiles, settings: settings, night: true, scale: 1)
        let buildings = try XCTUnwrap(scene.root.sublayers?.first { $0.name == "buildings" })
        let colors = buildings.sublayers?.compactMap { $0.sublayers?.first { $0.name == "facade" }?.backgroundColor }.map { String(describing: $0) } ?? []
        XCTAssertEqual(Set(colors).count, 11)
        settings.background = .transparent
        scene.configure(tiles: tiles, settings: settings, night: true, scale: 1)
        XCTAssertTrue(scene.root.sublayers?.first { $0.name == "sky" }?.isHidden == true)
    }
}
