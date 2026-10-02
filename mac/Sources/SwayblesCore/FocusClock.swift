// A focus session the person starts themselves. Pure state, driven by the clock you pass in.
import Foundation

public struct FocusClock: Equatable {
    public static let presets = [15, 25, 45]

    public private(set) var startedAt: Date?
    public private(set) var minutes = 25

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public mutating func start(minutes: Int, at now: Date) {
        self.minutes = max(1, minutes)
        startedAt = now
    }

    public mutating func stop() { startedAt = nil }

    public var duration: TimeInterval { TimeInterval(minutes * 60) }

    public func remaining(at now: Date) -> TimeInterval {
        guard let s = startedAt else { return 0 }
        return max(0, duration - now.timeIntervalSince(s))
    }

    /// 0 at the start, 1 when done.
    public func progress(at now: Date) -> Double {
        guard isRunning else { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }

    public func isDone(at now: Date) -> Bool { isRunning && remaining(at: now) <= 0 }

    /// "24" while more than a minute is left, then "0:42".
    public func remainingText(at now: Date) -> String {
        let r = Int(remaining(at: now).rounded(.up))
        return r >= 60 ? "\(Int((Double(r) / 60).rounded(.up)))" : String(format: "0:%02d", r)
    }
}
