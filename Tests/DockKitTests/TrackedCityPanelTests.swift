import XCTest
import AppKit
import ConfigKit
import CityKit
@testable import DockKit

final class TrackedCityPanelTests: XCTestCase {
    func testDecorationCannotTakeFocusOrInterceptDockInput() throws {
        _ = NSApplication.shared
        let panel = TrackedCityPanel()
        defer { panel.orderOut(nil) }
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey); XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertEqual(panel.level.rawValue, Int(CGWindowLevelForKey(.dockWindow)) + 1)
    }
    func testTrackerCanBeStoppedAndRestartedWithoutCreatingCustomDockWindows() {
        _ = NSApplication.shared
        let tracker = SystemDockCityTracker()
        var settings = CitySettings(); settings.enabled = false
        tracker.start(settings: settings); tracker.stop()
        tracker.start(settings: settings); tracker.stop()
        XCTAssertFalse(NSApp.windows.contains { $0 is TrackedCityPanel && $0.isVisible })
    }
}
