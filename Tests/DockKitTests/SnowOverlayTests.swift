import XCTest
import AppKit
import ConfigKit
import SnowCore
import CityKit
@testable import DockKit

final class SnowOverlayTests: XCTestCase {
    func testBottomAndSideDocksUseObservedUpperEdge() throws {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 700)
        for (orientation, rect) in [("bottom", CGRect(x: 100, y: 640, width: 300, height: 50)),
                                    ("left", CGRect(x: 0, y: 100, width: 50, height: 300)),
                                    ("right", CGRect(x: 950, y: 100, width: 50, height: 300))] {
            let item = SystemDockItem(index: 0, role: "AXDockItem", subrole: "AXApplicationDockItem", title: "", axFrame: rect)
            let snapshot = SystemDockSnapshot(pid: 1, orientation: orientation, tileSize: nil, autohide: nil,
                axListFrame: rect, items: [item], dockWindowFrame: rect, dockWindowLayer: 20, incomplete: false)
            let surface = try XCTUnwrap(SnowWindowMetadata.dockSurface(snapshot, primaryMaxY: 700, screens: [screen]))
            XCTAssertEqual(surface.kind, .dock); XCTAssertEqual(surface.frame.y, rect.minY)
            XCTAssertEqual(surface.frame.width, rect.width)
        }
    }
    func testSnowDecorationNeverTakesFocusOrMouseInput() {
        _ = NSApplication.shared
        let panel = SnowOverlayPanel(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        defer { panel.orderOut(nil) }
        XCTAssertFalse(panel.canBecomeKey); XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertEqual(panel.level.rawValue, Int(CGWindowLevelForKey(.dockWindow)) + 2)
    }
    func testCGMetadataFiltersOwnTransparentAndElevatedWindowsWithoutTitles() {
        func row(_ id: Int, pid: Int = 20, layer: Int = 0, alpha: Double = 1) -> [String: Any] {
            [kCGWindowNumber as String: NSNumber(value: id), kCGWindowOwnerPID as String: NSNumber(value: pid),
             kCGWindowLayer as String: NSNumber(value: layer), kCGWindowAlpha as String: NSNumber(value: alpha),
             kCGWindowBounds as String: CGRect(x: 10, y: 20, width: 200, height: 150).dictionaryRepresentation]
        }
        let decoded = SnowWindowMetadata.decode([row(1), row(2, pid: 99), row(3, layer: 20), row(4, alpha: 0), row(5)], ownPID: 99)
        XCTAssertEqual(decoded.map(\.id), [1, 5])
        XCTAssertEqual(decoded.first?.frame.y, 20)
    }
    func testOffscreenSnowRendererDrawsAndClearRemovesAllPixels() throws {
        _ = NSApplication.shared
        let view = SnowOverlayView(size: CGSize(width: 160, height: 160))
        view.simulation.updateSurfaces([SnowSurface(id: 1, frame: SnowRect(x: 10, y: 80, width: 140, height: 60))], elapsed: 0.1)
        for x in stride(from: 20.0, to: 140, by: 4) { XCTAssertTrue(view.simulation.deposit(on: 1, x: x, amount: 35)) }
        func visiblePixels() throws -> Int {
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            var count = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 { count += 1 }
            }
            return count
        }
        XCTAssertGreaterThan(try visiblePixels(), 100)
        view.simulation.clear()
        XCTAssertEqual(try visiblePixels(), 0)
    }
    func testSnowCanStopRestartAndPauseWithoutLeakingVisiblePanels() {
        _ = NSApplication.shared
        let controller = SnowOverlayController()
        var settings = SnowSettings(); settings.enabled = false
        controller.start(settings: settings); controller.clearSnow(); controller.stop()
        controller.start(settings: settings); controller.update(settings: settings); controller.stop()
        XCTAssertFalse(NSApp.windows.contains { $0 is SnowOverlayPanel && $0.isVisible })
    }
}
