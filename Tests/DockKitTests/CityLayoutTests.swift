import AppKit
import XCTest
import ConfigKit
import CityKit
@testable import DockKit

final class CityLayoutTests: XCTestCase {
    func testBuildingsUseActualCellsAndKeepIdentityWhenReordered() {
        let view = DockContentView(frame: NSRect(x: 0, y: 0, width: 360, height: 82))
        let a = DockItem.app(bundlePath: "/Applications/Alpha.app", label: "Alpha")
        let b = DockItem.app(bundlePath: "/Applications/Beta.app", label: "Beta")
        var tiles: [CityTile] = []
        view.onCityLayout = { tiles = $0 }
        view.configure(items: [a, .separator, b], iconSize: 52, running: [])
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(tiles.count, 2)
        let original = tiles.map(\.id)
        func cells(_ v: NSView) -> [DockItemCell] {
            v.subviews.flatMap { child in (child as? DockItemCell).map { [$0] } ?? cells(child) }
        }
        for cell in cells(view) {
            let rect = cell.convert(cell.bounds, to: view)
            let tile = tiles.first { $0.id.hasPrefix(cell.item.appPath ?? "!") }
            XCTAssertEqual(tile?.center ?? -1, Double(rect.midX), accuracy: 0.01)
        }
        view.configure(items: [b, .separator, a], iconSize: 52, running: [])
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(tiles.map(\.id), Array(original.reversed()))
    }

    func testDecorationPanelAlwaysIgnoresInputAndStopsWhenDisabled() {
        let dock = DockPanel(contentRect: NSRect(x: 50, y: 50, width: 300, height: 80))
        let city = CityPanel(dock: dock)
        defer { city.stop(); dock.orderOut(nil) }
        XCTAssertTrue(city.ignoresMouseEvents)
        XCTAssertFalse(city.canBecomeKey)
        XCTAssertTrue(dock.childWindows?.contains(city) ?? false)
        var settings = CitySettings(); settings.enabled = false
        city.configure(tiles: [], settings: settings, edge: .bottom)
        XCTAssertFalse(city.isVisible)
    }

    func testCrowdedDockUsesOneCompactStackForIconsAndBuildings() {
        let view = DockContentView(frame: NSRect(x: 0, y: 0, width: 420, height: 90))
        let items = (0..<30).map { DockItem.app(bundlePath: "/Applications/App\($0).app", label: nil) }
        view.configure(items: items, iconSize: 52, running: [], maxLength: 420)
        view.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(view.fittingSize().width, 421)
    }
}
