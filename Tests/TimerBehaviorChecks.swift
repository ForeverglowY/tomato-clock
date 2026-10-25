import Foundation

@main
struct TimerBehaviorChecks {
    @MainActor
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        var normal = TimerEngine(duration: 60)
        normal.start(at: start)
        precondition(normal.advance(to: start.addingTimeInterval(75)) == 60)
        precondition(!normal.isRunning && normal.remaining == 0)

        for kind in [SessionKind.focus, .breakTime] {
            var timer = TimerEngine(kind: kind, duration: 60)
            timer.continuesAfterDeadline = true
            timer.start(at: start)
            precondition(timer.advance(to: start.addingTimeInterval(60)) == 60)
            precondition(timer.isRunning && timer.remaining == 0 && timer.kind == kind)
            precondition(timer.advance(to: start.addingTimeInterval(80)) == 20)
            precondition(timer.remaining == -20 && timer.isRunning)
            precondition(timer.pause(at: start.addingTimeInterval(85)) == 5)
            precondition(timer.remaining == -25 && !timer.isRunning)
            precondition(timer.advance(to: start.addingTimeInterval(100)) == 0)
            timer.start(at: start.addingTimeInterval(100))
            precondition(timer.advance(to: start.addingTimeInterval(110)) == 10)
            precondition(timer.remaining == -35 && timer.isRunning)
            timer.prepare(kind.next, duration: 30)
            precondition(timer.remaining == 30 && !timer.isRunning && timer.kind == kind.next)
        }

        let suite = "TomatoClock.BehaviorChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TomatoStore(defaults: defaults)
        precondition(!store.continueAfterReminder)
        store.setDailyFocusGoalMinutes(720)
        store.setContinueAfterReminder(true)
        precondition(TomatoStore(defaults: defaults).continueAfterReminder)
        for kind in [SessionKind.focus, .breakTime] {
            precondition(store.kind == kind)
            store.toggleRunning()
            store.finishCurrentPhase()
            store.switchSession()
            store.stopCurrentSession()
            store.setContinueAfterReminder(false)
            precondition(store.isRunning && store.kind == kind && store.continueAfterReminder)
            Thread.sleep(forTimeInterval: 0.6)
            store.toggleRunning()
            precondition(!store.isRunning && store.hasActiveSession)
            precondition(store.sessionRecords.last?.kind == kind)
            precondition((store.sessionRecords.last?.duration ?? 0) >= 0.5)
            store.finishCurrentPhase()
            precondition(store.kind == kind.next && !store.hasActiveSession && !store.isRunning)
        }
        precondition(store.sessionRecords.count == 2)
        precondition(store.todayStats.focusSeconds >= 0.5 && store.todayStats.breakSeconds >= 0.5)
        print("PASS: default deadline, focus/rest overtime, pause/resume, manual transitions, settings persistence, and recorded durations")
    }
}
