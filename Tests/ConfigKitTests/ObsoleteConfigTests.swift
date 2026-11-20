import XCTest
@testable import ConfigKit

final class ObsoleteConfigTests: XCTestCase {
    func testV4ObsoletePayloadIsIgnoredWithoutLosingCityOrLoginPreference() throws {
        var original = Config(); original.schemaVersion = 4
        original.city.timeMode = .night; original.city.size = .large
        original.global.launchAtLogin = true
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        // Migration fixture only: this removed key is not decoded or re-encoded.
        for obsolete: Any in [["enabled": true, "fallVector": ["x": 30, "y": 60]], "invalid old payload", NSNull()] {
            object["snow"] = obsolete
            let decoded = try JSONDecoder().decode(Config.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertEqual(decoded.city, original.city); XCTAssertTrue(decoded.global.launchAtLogin)
            XCTAssertEqual(ConfigStore.migrate(decoded).schemaVersion, Config.currentSchemaVersion)
            let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
            XCTAssertNil(encoded["snow"])
        }
    }
    func testMigratedV4DataSavesWithBackupAndRecovers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(directory: directory)
        var original = Config(); original.schemaVersion = 4; original.city.lightIntensity = 0.3
        original.global.launchAtLogin = true
        try store.save(original)
        // Real v4 fixture survives in the backup after the first v5 save.
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.fileURL)) as? [String: Any])
        document["snow"] = ["enabled": true]
        try JSONSerialization.data(withJSONObject: document).write(to: store.fileURL)
        let migrated = store.load()
        XCTAssertEqual(migrated.schemaVersion, 5)
        try store.save(migrated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path + ".bak"))
        let backup = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.fileURL.appendingPathExtension("bak"))) as? [String: Any])
        XCTAssertNotNil(backup["snow"])
        try Data("broken".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load().city.lightIntensity, 0.3)
        XCTAssertTrue(store.load().global.launchAtLogin)
    }
}
