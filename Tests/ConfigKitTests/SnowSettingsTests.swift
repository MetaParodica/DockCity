import XCTest
@testable import ConfigKit

final class SnowSettingsTests: XCTestCase {
    func testLegacyConfigDefaultsSnowAndPreservesCity() throws {
        var config = Config(); config.city.timeMode = .night
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        object["schemaVersion"] = 3; object.removeValue(forKey: "snow")
        let loaded = try JSONDecoder().decode(Config.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(loaded.snow, SnowSettings()); XCTAssertEqual(loaded.city.timeMode, .night)
        XCTAssertEqual(ConfigStore.migrate(loaded).schemaVersion, 4)
    }
    func testSnowSettingsRoundTripAndDepthClamps() throws {
        var settings = SnowSettings(); settings.intensity = .flurry; settings.accumulateOnDock = false
        settings.reduceMotion = true; settings.maximumDepth = 23
        let restored = try JSONDecoder().decode(SnowSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored, settings)
        for (raw, expected) in [("-50", 2.0), ("100000", 30.0)] {
            let data = Data("{\"maximumDepth\":\(raw)}".utf8)
            XCTAssertEqual(try JSONDecoder().decode(SnowSettings.self, from: data).maximumDepth, expected)
        }
    }
    func testSnowConfigurationPersistsAndBackupRecovers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(directory: directory)
        var config = Config(); config.snow.enabled = false; config.snow.intensity = .steady
        try store.save(config); XCTAssertEqual(store.load().snow, config.snow)
        try store.save(Config()); try Data("broken".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load().snow, config.snow)
    }
}
