import XCTest
@testable import SnowCore

final class SnowGeometryTests: XCTestCase {
    func testMultiDisplayProjectionKeepsNegativeOriginsAndClipsByIntersection() {
        let a = SnowSurface(id: 1, frame: SnowRect(x: -800, y: -200, width: 400, height: 300))
        let b = SnowSurface(id: 2, frame: SnowRect(x: 100, y: 100, width: 300, height: 200))
        let local = SnowScene.local([a, b], display: SnowRect(x: -1000, y: -300, width: 1000, height: 800))
        XCTAssertEqual(local.count, 1); XCTAssertEqual(local[0].frame.x, 200); XCTAssertEqual(local[0].frame.y, 100)
    }
    func testInvalidAndDuplicateSurfacesAreExcludedWithoutReordering() {
        let a = SnowSurface(id: 3, frame: SnowRect(x: 0, y: 0, width: 100, height: 100))
        let b = SnowSurface(id: 2, frame: SnowRect(x: 0, y: 10, width: 200, height: 100))
        let invalid = SnowSurface(id: 1, frame: SnowRect(x: .nan, y: 0, width: 100, height: 100))
        XCTAssertEqual(SnowScene.validated([invalid, a, b, a]).map(\.id), [3, 2])
    }
    func testForegroundFullscreenSuppressesButRearMaximizedWindowDoesNot() {
        let full = SnowSurface(id: 1, frame: SnowRect(x: 0, y: 0, width: 500, height: 500))
        let small = SnowSurface(id: 2, frame: SnowRect(x: 30, y: 30, width: 100, height: 100))
        XCTAssertTrue(SnowScene.fullscreen(in: [full, small], width: 500, height: 500))
        XCTAssertFalse(SnowScene.fullscreen(in: [small, full], width: 500, height: 500))
    }
}
