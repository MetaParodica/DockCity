import ApplicationServices

public enum DockAccessibility {
    public static var isTrusted: Bool { AXIsProcessTrusted() }
    @discardableResult public static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
