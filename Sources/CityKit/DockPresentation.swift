import Foundation

/// Short bad samples are held, but permission/process/screen invalidation is immediate.
public struct DockSampleGrace {
    private var lastGood: Double?
    public init() {}
    public mutating func reset() { lastGood = nil }
    public mutating func accept(now: Double) { lastGood = now }
    public func canHold(now: Double) -> Bool {
        guard let lastGood else { return false }
        return now >= lastGood && now - lastGood <= 0.22
    }
}

/// Interrupted reveal/hide motion continues from its current value.
public struct DockSlide {
    private var from = 0.0, target = 0.0, start = 0.0, duration = 0.0
    public init() {}
    public mutating func finish() { from = target; duration = 0 }
    public func value(at now: Double) -> Double {
        guard duration > 0 else { return target }
        let t = min(1, max(0, (now - start) / duration))
        let eased = t * t * (3 - 2 * t)
        return from + (target - from) * eased
    }
    public mutating func set(visible: Bool, now: Double, delay: Double = 0, duration: Double) {
        let next = visible ? 1.0 : 0.0
        guard next != target else { return }
        from = value(at: now); target = next; start = now + max(0, delay)
        self.duration = max(0, duration)
    }
}
