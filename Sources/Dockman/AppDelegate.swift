import AppKit
import DockKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: DockmanController!
    private var statusItem: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = DockmanController()
        controller.start()
        statusItem = StatusItemController(controller: controller)

        // Accessibility is requested only if the user enables window summoning.

        // Register the dockman:// scripting scheme (docs/01 §4.6).
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string),
              let command = DockmanURL.parse(url) else { return }
        controller.handle(command)
    }
}
