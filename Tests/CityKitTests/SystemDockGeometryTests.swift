import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import CityKit

final class SystemDockGeometryTests: XCTestCase {
    func testAXCoordinatesMapToCocoaWithoutPixelScaling() {
        let rect = SystemDockGeometry.cocoaFrame(axFrame: CGRect(x: 320, y: 920, width: 64, height: 64), primaryMaxY: 1080)
        XCTAssertEqual(rect, CGRect(x: 320, y: 96, width: 64, height: 64))
        // AX and NSScreen use logical screen coordinates. Do not multiply by
        // Retina backingScaleFactor; that would misalign a 2x display.
        XCTAssertEqual(rect.width, 64)
    }
    func testDisplaysAboveAndLeftKeepNegativeGlobalCoordinates() {
        let above = SystemDockGeometry.cocoaFrame(axFrame: CGRect(x: 50, y: -300, width: 52, height: 52), primaryMaxY: 1080)
        XCTAssertEqual(above.minY, 1328)
        let left = SystemDockGeometry.cocoaFrame(axFrame: CGRect(x: -1400, y: 900, width: 48, height: 48), primaryMaxY: 1080)
        XCTAssertEqual(left.minX, -1400)
        XCTAssertEqual(left.minY, 132)
    }
    func testScreenSelectedByIntersectionNotMainWindowFocus() {
        let screens = [CGRect(x: 0, y: 0, width: 1920, height: 1080), CGRect(x: -1600, y: 0, width: 1600, height: 900)]
        XCTAssertEqual(SystemDockGeometry.screenIndex(items: [CGRect(x: -800, y: 10, width: 300, height: 64)], screens: screens), 1)
        XCTAssertNil(SystemDockGeometry.screenIndex(items: [CGRect(x: 500, y: -70, width: 64, height: 64)], screens: screens))
    }
    func testBottomPlanCoversRealIconsAndAnInwardStripWithoutInventingSpacing() throws {
        let items = [CGRect(x: 100, y: 10, width: 52, height: 52), CGRect(x: 183, y: 10, width: 71, height: 71)]
        let plan = try XCTUnwrap(SystemDockGeometry.plan(items: items, screen: CGRect(x: 0, y: 0, width: 1000, height: 700), orientation: .bottom))
        XCTAssertEqual(plan.panelFrame, CGRect(x: 100, y: 10, width: 154, height: 161))
        XCTAssertEqual(plan.visibleItems, items)
        for rect in items { XCTAssertTrue(plan.panelFrame.contains(rect)) }
    }
    func testVerticalPlansAndScreenClipping() throws {
        let screen = CGRect(x: -1000, y: 0, width: 1000, height: 800)
        let left = try XCTUnwrap(SystemDockGeometry.plan(items: [CGRect(x: -1000, y: 100, width: 60, height: 300)], screen: screen, orientation: .left))
        XCTAssertEqual(left.panelFrame, CGRect(x: -1000, y: 100, width: 150, height: 300))
        let right = try XCTUnwrap(SystemDockGeometry.plan(items: [CGRect(x: -60, y: 100, width: 60, height: 300)], screen: screen, orientation: .right))
        XCTAssertEqual(right.panelFrame, CGRect(x: -150, y: 100, width: 150, height: 300))
        let clipped = try XCTUnwrap(SystemDockGeometry.plan(items: [CGRect(x: -10, y: 740, width: 50, height: 60)], screen: screen, orientation: .bottom))
        XCTAssertTrue(screen.contains(clipped.panelFrame))
    }
    func testAbsentAndInvalidGeometryProducesNoOverlay() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 700)
        XCTAssertNil(SystemDockGeometry.plan(items: [], screen: screen, orientation: .bottom))
        XCTAssertNil(SystemDockGeometry.plan(items: [.zero, .null, CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 20)], screen: screen, orientation: .bottom))
    }
    func testRolesNotLocalizedTitlesClassifyItemsAndMissingFramesSurviveJSON() throws {
        let app = SystemDockItem(index: 0, role: "AXDockItem", subrole: "AXApplicationDockItem", title: "Finder", axFrame: nil)
        let separator = SystemDockItem(index: 1, role: "AXSeparator", subrole: "", title: "", axFrame: nil)
        let trash = SystemDockItem(index: 2, role: "AXDockItem", subrole: "AXTrashDockItem", title: "휴지통", axFrame: nil)
        let unknown = SystemDockItem(index: 3, role: "AXDockItem", subrole: "", title: "Trash", axFrame: nil)
        XCTAssertEqual(app.kind, .application); XCTAssertEqual(separator.kind, .separator)
        XCTAssertEqual(trash.kind, .trash); XCTAssertEqual(unknown.kind, .other)
        let restored = try JSONDecoder().decode([SystemDockItem].self, from: JSONEncoder().encode([app, separator, trash, unknown]))
        XCTAssertEqual(restored, [app, separator, trash, unknown])
        XCTAssertNil(restored[2].axFrame)
    }
}
