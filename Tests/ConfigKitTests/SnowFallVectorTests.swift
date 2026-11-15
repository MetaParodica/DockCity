import XCTest
@testable import ConfigKit

final class SnowFallVectorTests: XCTestCase {
    func testOldSnowSettingsDefaultToDownwardFlow() throws {
        let settings = try JSONDecoder().decode(SnowSettings.self, from: Data(#"{"enabled":true,"intensity":"steady"}"#.utf8))
        XCTAssertEqual(settings.fallVector, SnowFallVector(x: 0, y: 32))
    }
    func testArrowControlMapsScreenAxesAndClampsToCircle() {
        XCTAssertEqual(SnowFallVector.fromControl(x: 0, y: 78, radius: 78), SnowFallVector(x: 0, y: 180))
        XCTAssertEqual(SnowFallVector.fromControl(x: -78, y: 0, radius: 78), SnowFallVector(x: -180, y: 0))
        XCTAssertEqual(SnowFallVector.fromControl(x: 0, y: -78, radius: 78).y, -180)
        let diagonal = SnowFallVector.fromControl(x: 78, y: 78, radius: 78)
        XCTAssertEqual(diagonal.speed, 180, accuracy: 1e-9)
        XCTAssertEqual(diagonal.x, diagonal.y, accuracy: 1e-9)
        XCTAssertEqual(SnowFallVector.fromControl(x: 0, y: 39, radius: 78).speed, 90)
    }
    func testZeroVectorAndSpeedAdjustmentPreserveDirection() {
        let zero = SnowFallVector.fromControl(x: 0, y: 0, radius: 78)
        XCTAssertEqual(zero.speed, 0)
        XCTAssertEqual(zero.withSpeed(40), SnowFallVector(x: 0, y: 40))
        let diagonal = SnowFallVector(x: -30, y: 40).withSpeed(100)
        XCTAssertEqual(diagonal.x, -60, accuracy: 1e-9); XCTAssertEqual(diagonal.y, 80, accuracy: 1e-9)
        XCTAssertEqual(diagonal.withSpeed(-5).speed, 0)
    }
    func testKeyboardRotationKeepsSpeedAndChangesDirection() {
        let right = SnowFallVector(x: 0, y: 32).rotated(degrees: -90)
        XCTAssertEqual(right.x, 32, accuracy: 1e-9); XCTAssertEqual(right.y, 0, accuracy: 1e-9)
        XCTAssertEqual(right.rotated(degrees: 360).speed, 32, accuracy: 1e-9)
    }
    func testExtremeAndInvalidInputIsFiniteAndBounded() {
        for vector in [SnowFallVector(x: .greatestFiniteMagnitude, y: .greatestFiniteMagnitude),
                       SnowFallVector(x: .nan, y: 10), SnowFallVector(x: 0, y: -.infinity),
                       SnowFallVector.fromControl(x: 1e300, y: -1e300, radius: 1e-300),
                       SnowFallVector.fromControl(x: 1, y: 2, radius: 0)] {
            XCTAssertTrue(vector.x.isFinite && vector.y.isFinite)
            XCTAssertLessThanOrEqual(vector.speed, 180.000000001)
        }
        XCTAssertEqual(SnowFallVector().rotated(degrees: .infinity), SnowFallVector())
    }
    func testVectorSettingsPersistAndRecoverFromBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(directory: directory)
        var config = Config(); config.snow.fallVector = SnowFallVector(x: -45, y: 60)
        try store.save(config)
        XCTAssertEqual(store.load().snow.fallVector, config.snow.fallVector)
        try store.save(Config()); try Data("broken".utf8).write(to: store.fileURL)
        XCTAssertEqual(store.load().snow.fallVector, config.snow.fallVector)
    }
}
