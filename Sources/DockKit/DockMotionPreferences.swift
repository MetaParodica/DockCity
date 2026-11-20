import Foundation

/// Read only. Absent private preference keys use documented-as-estimates fallbacks.
struct DockMotionPreferences {
    let delay: Double
    let duration: Double
    let usesEstimate: Bool
    init() {
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        let delay = prefs?.object(forKey: "autohide-delay") as? NSNumber
        let modifier = prefs?.object(forKey: "autohide-time-modifier") as? NSNumber
        usesEstimate = delay == nil || modifier == nil
        self.delay = Self.bound(delay?.doubleValue ?? 0.2, fallback: 0.2)
        self.duration = Self.bound(modifier?.doubleValue ?? 0.5, fallback: 0.5)
    }
    private static func bound(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? min(3, max(0, value)) : fallback
    }
}
