import AppKit

public struct RunningAppInfo: Equatable {
    public let bundleID: String?
    public let bundlePath: String?
    public let name: String
    public let isActive: Bool
}

/// Notification-driven app state for the buildings above the real Dock.
public final class AppActivityMonitor {
    public var onChange: (() -> Void)?
    private var tokens: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private let debounce: TimeInterval

    public init(debounce: TimeInterval = 0.25) {
        self.debounce = debounce
    }

    public func start() {
        let nc = NSWorkspace.shared.notificationCenter
        for name: NSNotification.Name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
        ] {
            tokens.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.schedule()
            })
        }
    }

    // Coalesce bursts and let `runningApplications` settle after a terminate before
    // we snapshot (avoids a momentarily stale zone — the didTerminate race).
    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    public func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        tokens.forEach { nc.removeObserver($0) }
        tokens.removeAll()
        pending?.cancel()
        pending = nil
    }

    /// Snapshot of running regular apps.
    public func snapshot() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { app in
                RunningAppInfo(bundleID: app.bundleIdentifier,
                               bundlePath: app.bundleURL?.path,
                               name: app.localizedName ?? (app.bundleURL?.deletingPathExtension().lastPathComponent ?? "App"),
                               isActive: app.isActive)
            }
    }
}
