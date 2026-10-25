import Foundation

enum SessionKind: String, Codable, Sendable {
    case focus
    case breakTime

    var next: SessionKind { self == .focus ? .breakTime : .focus }
}

struct TimerEngine: Equatable, Sendable {
    var kind: SessionKind = .focus
    var duration: TimeInterval
    var remaining: TimeInterval
    var isRunning = false
    var continuesAfterDeadline = false
    private(set) var lastUpdate: Date?

    init(kind: SessionKind = .focus, duration: TimeInterval) {
        self.kind = kind
        self.duration = duration
        self.remaining = duration
    }

    mutating func start(at date: Date) {
        guard !isRunning, remaining > 0 || continuesAfterDeadline else { return }
        isRunning = true
        lastUpdate = date
    }

    mutating func pause(at date: Date) -> TimeInterval {
        let elapsed = advance(to: date)
        isRunning = false
        lastUpdate = nil
        return elapsed
    }

    mutating func reset(duration: TimeInterval) {
        self.duration = duration
        remaining = duration
        isRunning = false
        lastUpdate = nil
    }

    mutating func prepare(_ newKind: SessionKind, duration: TimeInterval) {
        kind = newKind
        reset(duration: duration)
    }

    /// Advances using wall-clock time and returns the amount that should be recorded in statistics.
    mutating func advance(to date: Date) -> TimeInterval {
        guard isRunning, let lastUpdate else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(lastUpdate))
        let counted = continuesAfterDeadline ? elapsed : min(elapsed, max(remaining, 0))
        remaining -= counted
        self.lastUpdate = date
        if remaining <= 0, !continuesAfterDeadline {
            remaining = 0
            isRunning = false
            self.lastUpdate = nil
        }
        return counted
    }
}
