import AppKit
import Combine
import Foundation

enum AlertSound: String, CaseIterable, Identifiable {
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case hero = "Hero"
    case tink = "Tink"
    case purr = "Purr"
    case basso = "Basso"
    case submarine = "Submarine"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glass: "玻璃"
        case .ping: "提示"
        case .pop: "清脆"
        case .hero: "英雄"
        case .tink: "轻响"
        case .purr: "柔和"
        case .basso: "低音"
        case .submarine: "潜水艇"
        }
    }
}

@MainActor
final class TomatoStore: ObservableObject {
    private enum Keys {
        static let focusMinutes = "focusMinutes"
        static let breakMinutes = "breakMinutes"
        static let dailyStats = "dailyStats"
        static let alertSound = "alertSound"
        static let alertVolume = "alertVolume"
        static let sessionRecords = "sessionRecords"
    }

    struct DayStats: Codable, Equatable {
        var focusSeconds: TimeInterval = 0
        var breakSeconds: TimeInterval = 0
    }

    struct SessionRecord: Codable, Identifiable, Equatable {
        let id: UUID
        let kind: SessionKind
        let startDate: Date
        let endDate: Date
        let duration: TimeInterval
    }

    struct DailyStatBar: Identifiable {
        let date: Date
        let kind: SessionKind
        let seconds: TimeInterval

        var id: String { "\(date.timeIntervalSinceReferenceDate)-\(kind.rawValue)" }
    }

    @Published private(set) var focusMinutes: Int {
        didSet {
            defaults.set(focusMinutes, forKey: Keys.focusMinutes)
            if !engine.isRunning, engine.kind == .focus { engine.reset(duration: focusDuration) }
        }
    }
    @Published private(set) var breakMinutes: Int {
        didSet {
            defaults.set(breakMinutes, forKey: Keys.breakMinutes)
            if !engine.isRunning, engine.kind == .breakTime { engine.reset(duration: breakDuration) }
        }
    }
    @Published private(set) var engine: TimerEngine
    @Published private(set) var todayStats = DayStats()
    @Published private(set) var alertSound: AlertSound {
        didSet { defaults.set(alertSound.rawValue, forKey: Keys.alertSound) }
    }
    @Published private(set) var alertVolume: Double {
        didSet { defaults.set(alertVolume, forKey: Keys.alertVolume) }
    }
    @Published private(set) var sessionRecords: [SessionRecord] = []
    @Published private(set) var statisticsStartDate: Date
    @Published private(set) var statisticsEndDate: Date

    private let defaults: UserDefaults
    private var allStats: [String: DayStats] = [:]
    private var timer: Timer?
    private var currentDayKey: String
    private var playingSound: NSSound?
    private var runningSegmentStart: Date?
    private var runningSegmentBudget: TimeInterval = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedFocus = defaults.integer(forKey: Keys.focusMinutes)
        let storedBreak = defaults.integer(forKey: Keys.breakMinutes)
        let validFocus = min(max(storedFocus > 0 ? storedFocus : 25, 1), 180)
        let validBreak = min(max(storedBreak > 0 ? storedBreak : 5, 1), 60)
        focusMinutes = validFocus
        breakMinutes = validBreak
        alertSound = AlertSound(rawValue: defaults.string(forKey: Keys.alertSound) ?? "") ?? .glass
        alertVolume = defaults.object(forKey: Keys.alertVolume) == nil
            ? 0.8
            : min(max(defaults.double(forKey: Keys.alertVolume), 0), 1)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        statisticsStartDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        statisticsEndDate = today
        engine = TimerEngine(duration: TimeInterval(validFocus * 60))
        currentDayKey = Self.dayKey(for: .now)
        loadStats()
        loadSessionRecords()
        todayStats = allStats[currentDayKey] ?? DayStats()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    var focusDuration: TimeInterval { TimeInterval(focusMinutes * 60) }
    var breakDuration: TimeInterval { TimeInterval(breakMinutes * 60) }
    var isRunning: Bool { engine.isRunning }
    var kind: SessionKind { engine.kind }
    var menuBarTitle: String { "\(kind == .focus ? "🍅" : "☕️") \(formattedRemaining)" }
    var formattedRemaining: String { Self.formatCountdown(engine.remaining) }
    var statusText: String {
        if engine.isRunning { return kind == .focus ? "正在专注" : "正在休息" }
        if engine.remaining == 0 { return kind == .focus ? "专注完成" : "休息完成" }
        return kind == .focus ? "准备专注" : "准备休息"
    }

    var filteredSessionRecords: [SessionRecord] {
        let interval = statisticsDateInterval
        return sessionRecords
            .filter { $0.endDate > interval.start && $0.startDate < interval.end }
            .sorted { $0.startDate > $1.startDate }
    }

    var dailyStatBars: [DailyStatBar] {
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: statisticsStartDate)
        let last = calendar.startOfDay(for: statisticsEndDate)
        var result: [DailyStatBar] = []
        while date <= last {
            let stats = allStats[Self.dayKey(for: date)] ?? DayStats()
            result.append(DailyStatBar(date: date, kind: .focus, seconds: stats.focusSeconds))
            result.append(DailyStatBar(date: date, kind: .breakTime, seconds: stats.breakSeconds))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    var filteredTotals: DayStats {
        dailyStatBars.reduce(into: DayStats()) { totals, bar in
            if bar.kind == .focus { totals.focusSeconds += bar.seconds }
            else { totals.breakSeconds += bar.seconds }
        }
    }

    func setFocusMinutes(_ minutes: Int) {
        focusMinutes = min(max(minutes, 1), 180)
    }

    func setBreakMinutes(_ minutes: Int) {
        breakMinutes = min(max(minutes, 1), 60)
    }

    func setAlertSound(_ sound: AlertSound) {
        alertSound = sound
    }

    func setAlertVolume(_ volume: Double) {
        alertVolume = min(max(volume, 0), 1)
    }

    func previewAlertSound() {
        playAlertSound()
    }

    func setStatisticsStartDate(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        statisticsStartDate = min(day, statisticsEndDate)
    }

    func setStatisticsEndDate(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        statisticsEndDate = max(day, statisticsStartDate)
    }

    func selectStatisticsRange(days: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        statisticsEndDate = today
        statisticsStartDate = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
    }

    func terminateApplication() {
        if engine.isRunning {
            let now = Date.now
            record(engine.pause(at: now), for: engine.kind, at: now)
            finishRunningSegment(at: now)
        }
        NSApplication.shared.terminate(nil)
    }

    func toggleRunning() {
        let now = Date.now
        if engine.isRunning {
            record(engine.pause(at: now), for: engine.kind, at: now)
            finishRunningSegment(at: now)
        } else {
            if engine.remaining == 0 {
                engine.reset(duration: duration(for: engine.kind))
            }
            beginRunningSegment(at: now)
            engine.start(at: now)
        }
    }

    func resetCurrent() {
        if engine.isRunning {
            let now = Date.now
            record(engine.pause(at: now), for: engine.kind, at: now)
            finishRunningSegment(at: now)
        }
        engine.reset(duration: duration(for: engine.kind))
    }

    func switchSession() {
        if engine.isRunning {
            let now = Date.now
            record(engine.pause(at: now), for: engine.kind, at: now)
            finishRunningSegment(at: now)
        }
        let next = engine.kind.next
        engine.prepare(next, duration: duration(for: next))
    }

    func startPreparedSession() {
        if engine.remaining == 0 { switchSession() }
        let now = Date.now
        beginRunningSegment(at: now)
        engine.start(at: now)
    }

    private func tick() {
        rollDayIfNeeded(at: .now)
        let wasRunning = engine.isRunning
        let completedKind = engine.kind
        let elapsed = engine.advance(to: .now)
        record(elapsed, for: completedKind, at: .now)
        if wasRunning, !engine.isRunning, engine.remaining == 0 {
            finishRunningSegment(at: .now)
            let next = completedKind.next
            engine.prepare(next, duration: duration(for: next))
            playAlertSound()
            showCompletionAlert(completedKind: completedKind, nextKind: next)
        }
    }

    private var statisticsDateInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: statisticsStartDate)
        let endDay = calendar.startOfDay(for: statisticsEndDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return DateInterval(start: start, end: end)
    }

    private func beginRunningSegment(at date: Date) {
        runningSegmentStart = date
        runningSegmentBudget = engine.remaining
    }

    private func finishRunningSegment(at date: Date) {
        guard let start = runningSegmentStart else { return }
        let duration = min(max(date.timeIntervalSince(start), 0), runningSegmentBudget)
        runningSegmentStart = nil
        runningSegmentBudget = 0
        guard duration >= 0.5 else { return }
        let record = SessionRecord(
            id: UUID(),
            kind: engine.kind,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            duration: duration
        )
        sessionRecords.append(record)
        saveSessionRecords()
    }

    private func playAlertSound() {
        playingSound?.stop()
        guard let sound = NSSound(named: NSSound.Name(alertSound.rawValue)) else {
            NSSound.beep()
            return
        }
        sound.volume = Float(alertVolume)
        playingSound = sound
        sound.play()
    }

    private func showCompletionAlert(completedKind: SessionKind, nextKind: SessionKind) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = completedKind == .focus ? "专注结束" : "休息结束"
        alert.informativeText = nextKind == .breakTime
            ? "休息已准备好，点击菜单栏中的“开始休息”后才会开始计时。"
            : "下一轮专注已准备好，点击菜单栏中的“开始专注”后才会开始计时。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func duration(for kind: SessionKind) -> TimeInterval {
        kind == .focus ? focusDuration : breakDuration
    }

    private func record(_ seconds: TimeInterval, for kind: SessionKind, at date: Date) {
        guard seconds > 0 else { return }
        rollDayIfNeeded(at: date)
        if kind == .focus { todayStats.focusSeconds += seconds }
        else { todayStats.breakSeconds += seconds }
        allStats[currentDayKey] = todayStats
        saveStats()
    }

    private func rollDayIfNeeded(at date: Date) {
        let key = Self.dayKey(for: date)
        guard key != currentDayKey else { return }
        currentDayKey = key
        todayStats = allStats[key] ?? DayStats()
    }

    private func loadStats() {
        guard let data = defaults.data(forKey: Keys.dailyStats),
              let decoded = try? JSONDecoder().decode([String: DayStats].self, from: data) else { return }
        allStats = decoded
    }

    private func saveStats() {
        guard let data = try? JSONEncoder().encode(allStats) else { return }
        defaults.set(data, forKey: Keys.dailyStats)
    }

    private func loadSessionRecords() {
        guard let data = defaults.data(forKey: Keys.sessionRecords),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) else { return }
        sessionRecords = decoded
    }

    private func saveSessionRecords() {
        guard let data = try? JSONEncoder().encode(sessionRecords) else { return }
        defaults.set(data, forKey: Keys.sessionRecords)
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func formatStats(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        return "\(totalMinutes / 60) 小时 \(totalMinutes % 60) 分钟"
    }

    static func formatPreciseDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainingSeconds = total % 60
        if hours > 0 { return "\(hours)小时 \(minutes)分" }
        return "\(minutes)分 \(remainingSeconds)秒"
    }
}
