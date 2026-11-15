import AppKit
import SwiftUI
import ServiceManagement
import ConfigKit
import DockKit

final class DockCityController: ObservableObject {
    @Published private(set) var config: Config
    @Published private(set) var status = "Starting Dock tracking"
    @Published private(set) var saveError: String?
    @Published private(set) var snowStatus = "Starting snow"
    let tracker = SystemDockCityTracker()
    let snow = SnowOverlayController()
    private let store = ConfigStore()
    init() { config = store.load() }
    func start() {
        tracker.onStatus = { [weak self] in self?.status = $0 }
        tracker.onApplicationsChanged = { [weak self] in self?.objectWillChange.send() }
        tracker.onDockSnapshot = { [weak self] in self?.snow.setDockSnapshot($0) }
        tracker.tracksDockGeometry = config.snow.enabled && config.snow.accumulateOnDock
        snow.onStatus = { [weak self] in self?.snowStatus = $0 }
        snow.start(settings: config.snow)
        tracker.start(settings: config.city)
        if config.global.launchAtLogin, SMAppService.mainApp.status != .enabled {
            do { try SMAppService.mainApp.register() }
            catch { saveError = "Login registration: \(error.localizedDescription)" }
        }
    }
    func setCity(_ value: CitySettings) { config.city = value; persist(); tracker.update(settings: value) }
    func setSnow(_ value: SnowSettings) {
        config.snow = value; persist(); snow.update(settings: value)
        tracker.tracksDockGeometry = value.enabled && value.accumulateOnDock
    }
    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            config.global.launchAtLogin = value; persist()
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { saveError = error.localizedDescription }
    }
    private func persist() {
        config.schemaVersion = Config.currentSchemaVersion
        do { try store.save(config); saveError = nil }
        catch { saveError = "Could not save settings: \(error.localizedDescription)" }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = DockCityController()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindowController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "building.2.fill", accessibilityDescription: "Dock City")
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)
        let pause = NSMenuItem(title: "Pause / Resume city", action: #selector(toggleCity), keyEquivalent: "")
        pause.target = self; menu.addItem(pause)
        let snow = NSMenuItem(title: "Pause / Resume snow", action: #selector(toggleSnow), keyEquivalent: "")
        snow.target = self; menu.addItem(snow)
        let clear = NSMenuItem(title: "Clear settled snow", action: #selector(clearSnow), keyEquivalent: "")
        clear.target = self; menu.addItem(clear)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Dock City", action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit); statusItem.menu = menu
        controller.start()
        if !DockAccessibility.isTrusted { showSettings() }
    }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 530, height: 680),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Dock City"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: TrackingSettingsView(controller: controller))
            window.center(); settingsWindow = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.showWindow(nil); settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }
    @objc private func toggleCity() { var city = controller.config.city; city.enabled.toggle(); controller.setCity(city) }
    @objc private func toggleSnow() { var settings = controller.config.snow; settings.enabled.toggle(); controller.setSnow(settings) }
    @objc private func clearSnow() { controller.snow.clearSnow() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { controller.tracker.stop(); controller.snow.stop() }
}
