import XCTest
@testable import ConfigKit

final class TrackingMigrationTests: XCTestCase {
    func testLegacyCityMigratesFromFirstEnabledDockWithoutLosingOriginalData() throws {
        var disabledCity = CitySettings(); disabledCity.size = .small
        var selectedCity = CitySettings(); selectedCity.timeMode = .night
        selectedCity.buildings["com.apple.Safari"] = BuildingOverride(style: .glassTower, color: "#71A8B7")
        let docks = [DockModel(name: "Disabled", items: [], binding: .allSpaces, enabled: false, city: disabledCity),
                     DockModel(name: "Selected", items: [], binding: .allSpaces, city: selectedCity)]
        let config = Config(schemaVersion: 2, docks: docks, global: GlobalSettings(launchAtLogin: true))
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        document.removeValue(forKey: "city")
        let decoded = try JSONDecoder().decode(Config.self, from: JSONSerialization.data(withJSONObject: document))
        XCTAssertEqual(decoded.city, selectedCity); XCTAssertEqual(decoded.docks, docks)
        XCTAssertTrue(decoded.global.launchAtLogin)
        XCTAssertEqual(ConfigStore.migrate(decoded).schemaVersion, Config.currentSchemaVersion)
    }
    func testGlobalCityTakesPrecedenceAndNewDocumentsNeedNoCustomDocks() throws {
        var city = CitySettings(); city.size = .large; city.enabled = false
        let config = Config(city: city)
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.city, city); XCTAssertTrue(decoded.docks.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(Config.self, from: Data("{}".utf8)).city, CitySettings())
    }
    func testMigratedSettingsPersistAndRecoverFromBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(directory: directory)
        var city = CitySettings(); city.timeMode = .night
        try store.save(Config(city: city))
        try store.save(Config())
        try Data("broken".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load().city, city)
        XCTAssertTrue(store.load().docks.isEmpty)
    }
}
