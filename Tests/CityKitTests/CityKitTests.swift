import XCTest
import ConfigKit
@testable import CityKit

final class CityKitTests: XCTestCase {
    func testLaunchSwitchTerminateAndMissingBundleID() {
        let safari = CityAppState(bundleID: "com.apple.Safari", path: "/Safari.app", active: true)
        let finder = CityAppState(bundleID: "com.apple.finder", path: "/Finder.app", active: false)
        XCTAssertEqual(CityAppState.activity(bundleID: "com.apple.Safari", path: "/Safari.app", running: []), .inactive)
        XCTAssertEqual(CityAppState.activity(bundleID: "com.apple.Safari", path: "/Safari.app", running: [finder, safari]), .active)
        XCTAssertEqual(CityAppState.activity(bundleID: "com.apple.finder", path: "/Finder.app", running: [finder, safari]), .running)
        XCTAssertEqual(CityAppState.activity(bundleID: nil, path: "/Unknown.app", running: [CityAppState(bundleID: nil, path: "/Unknown.app", active: false)]), .running)
        XCTAssertEqual(CityAppState.activity(bundleID: nil, path: "/Unknown.app", running: [CityAppState(bundleID: nil, path: "/Other.app", active: true)]), .inactive)
        for i in 0..<100 {
            let states = [CityAppState(bundleID: safari.bundleID, path: safari.path, active: i % 2 == 0)]
            XCTAssertEqual(CityAppState.activity(bundleID: safari.bundleID, path: "/Safari.app", running: states), i % 2 == 0 ? .active : .running)
        }
    }

    func testTimeBoundariesAndOverrides() {
        for hour in 0..<24 {
            XCTAssertEqual(CitySettings.TimeMode.automatic.isNight(hour: hour), hour < 7 || hour >= 18)
            XCTAssertFalse(CitySettings.TimeMode.day.isNight(hour: hour))
            XCTAssertTrue(CitySettings.TimeMode.night.isNight(hour: hour))
        }
    }

    func testMappingAndUnknownAppFallback() {
        XCTAssertEqual(BuildingStyle.defaultStyle(bundleID: "com.apple.finder"), .warehouse)
        XCTAssertEqual(BuildingStyle.defaultStyle(bundleID: "com.apple.Safari"), .glassTower)
        XCTAssertEqual(BuildingStyle.defaultStyle(bundleID: "com.apple.Terminal"), .serverCenter)
        XCTAssertEqual(BuildingStyle.defaultStyle(bundleID: "com.apple.iCal"), .clockTower)
        XCTAssertEqual(BuildingStyle.defaultStyle(bundleID: "com.apple.Music"), .concertHall)
        XCTAssertEqual(BuildingStyle.defaultStyle(bundleID: nil), .office)
    }

    func testSettingsMigrationRoundTripAndDiskRestoration() throws {
        XCTAssertEqual(try JSONDecoder().decode(CitySettings.self, from: Data("{}".utf8)), CitySettings())
        var city = CitySettings()
        city.buildings["com.apple.Safari"] = BuildingOverride(style: .library, color: "#71A8B7")
        city.timeMode = .night; city.citizenDensity = .high; city.lightIntensity = 0.4
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(directory: directory)
        try store.save(Config(docks: [DockModel(name: "Town", items: [], binding: .allSpaces, city: city)]))
        XCTAssertEqual(ConfigStore(directory: directory).load().docks.first?.city, city)
        XCTAssertTrue(ConfigStore().directory.path.hasSuffix("com.metaparodica.DockCity"))
    }

    func testActorsReactToActivationAndStayBoundedAcrossResize() {
        var sim = CitySimulation(); var settings = CitySettings()
        sim.configure(width: 360, settings: settings, night: false)
        XCTAssertEqual(sim.citizens.count, 3); XCTAssertEqual(sim.vehicles.count, 2)
        sim.activate(CityTile(id: "Safari", bundleID: "com.apple.Safari", center: 150, width: 52, activity: .active))
        XCTAssertEqual(sim.citizens[0].destination, 150)
        XCTAssertEqual(sim.vehicles[1].destination, 150)
        let stationary = sim.citizens[0].x
        sim.step(seconds: 0); XCTAssertEqual(sim.citizens[0].x, stationary)
        var states = Set<String>()
        for _ in 0..<1000 {
            sim.step(seconds: 1 / 30)
            states.insert(sim.citizens[0].state.rawValue)
            for actor in sim.citizens + sim.vehicles { XCTAssertTrue((10...350).contains(actor.x)) }
        }
        XCTAssertTrue(states.isSuperset(of: ["walk", "enterBuilding", "idle", "exitBuilding", "wait"]))
        sim.configure(width: 110, settings: settings, night: true)
        for actor in sim.citizens + sim.vehicles { XCTAssertTrue((10...100).contains(actor.x)) }
        settings.citizenDensity = .off; settings.trafficEnabled = false
        sim.configure(width: 110, settings: settings, night: false)
        XCTAssertTrue(sim.citizens.isEmpty); XCTAssertTrue(sim.vehicles.isEmpty)
    }

    func testRapidActivationRetargetsWithoutTeleporting() {
        var sim = CitySimulation()
        sim.configure(width: 400, settings: CitySettings(), night: false)
        let initial = sim.citizens[0].x
        for i in 0..<50 {
            sim.activate(CityTile(id: String(i), bundleID: nil, center: Double(i * 9), width: 40, activity: .active))
        }
        XCTAssertEqual(sim.citizens[0].x, initial)
        XCTAssertEqual(sim.citizens[0].destination, 390)
    }
}
