import SwiftUI

struct ContentView: View {
    @ObservedObject var store: TomatoStore
    var onShowStatistics: (() -> Void)? = nil
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(store.kind == .focus ? "专注" : "休息",
                      systemImage: store.kind == .focus ? "brain.head.profile" : "cup.and.saucer.fill")
                    .font(.headline)
                Spacer()
                Text(store.statusText).foregroundStyle(.secondary)
            }

            Text(store.formattedRemaining)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .adaptiveGlassCard(cornerRadius: 18, tint: store.kind == .focus ? .red.opacity(0.12) : .green.opacity(0.12))

            HStack {
                Button(store.isRunning ? "暂停" : (store.hasActiveSession ? "继续" : (store.kind == .focus ? "开始专注" : "开始休息"))) {
                    store.toggleRunning()
                }
                .adaptivePrimaryButton(tint: store.kind == .focus ? .red : .green)
                .keyboardShortcut(.space, modifiers: [])

                if store.hasActiveSession {
                    Button(store.continueAfterReminder ? "结束" : "停止") {
                        if store.continueAfterReminder { store.finishCurrentPhase() }
                        else { store.stopCurrentSession() }
                    }
                        .disabled(store.isRunning)
                        .help(store.isRunning ? "请先暂停，再结束计时" : (store.continueAfterReminder ? "结束当前阶段，准备下一阶段，保留已记录时长" : "结束本轮并重置倒计时，保留已记录的时长"))
                } else {
                    Button("重置") { store.resetCurrent() }
                }
                Button(store.kind == .focus ? "切换到休息" : "切换到专注") { store.switchSession() }
                    .disabled(store.hasActiveSession)
                    .help(store.hasActiveSession ? "请先停止当前计时，再切换阶段" : "切换计时阶段")
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("专注时长")
                    durationInput(
                        value: Binding(get: { store.focusMinutes }, set: store.setFocusMinutes),
                        range: 1...180
                    )
                }
                GridRow {
                    Text("休息时长")
                    durationInput(
                        value: Binding(get: { store.breakMinutes }, set: store.setBreakMinutes),
                        range: 1...60
                    )
                }
                GridRow {
                    Text("每日目标")
                    durationInput(
                        value: Binding(
                            get: { store.dailyFocusGoalMinutes },
                            set: store.setDailyFocusGoalMinutes
                        ),
                        range: 1...720
                    )
                }
            }
            .padding(12)
            .adaptiveGlassCard(cornerRadius: 14)
            .disabled(store.hasActiveSession)

            Toggle("到时只提醒，手动结束", isOn: Binding(
                get: { store.continueAfterReminder },
                set: store.setContinueAfterReminder
            ))
            .toggleStyle(.switch)
            .disabled(store.hasActiveSession)
            .help("开启后，专注和休息到时仍继续计时；先暂停，再点击结束。下轮需手动开始。")

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("提示铃声")
                    HStack(spacing: 8) {
                        Picker("提示铃声", selection: Binding(
                            get: { store.alertSound },
                            set: store.setAlertSound
                        )) {
                            ForEach(AlertSound.allCases) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 112)
                        Button("试听") { store.previewAlertSound() }
                    }
                }
                GridRow {
                    Text("铃声音量")
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { store.alertVolume },
                            set: store.setAlertVolume
                        ), in: 0...1)
                        Text("\(Int((store.alertVolume * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                    }
                    .frame(width: 210)
                }
            }
            .padding(12)
            .adaptiveGlassCard(cornerRadius: 14)

            Divider()

            HStack(spacing: 14) {
                FocusGoalRing(progress: store.dailyFocusGoalProgress, size: 62, lineWidth: 8)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("今日专注目标").font(.headline)
                        if store.dailyFocusGoalAchieved {
                            Text("已达成")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    Text("\(TomatoStore.formatStats(store.todayStats.focusSeconds)) / \(store.dailyFocusGoalMinutes) 分钟")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("完成 \(store.dailyFocusGoalPercentage)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .adaptiveGlassCard(cornerRadius: 14, tint: .orange.opacity(0.12), interactive: true)

            HStack {
                Label(TomatoStore.formatStats(store.todayStats.focusSeconds), systemImage: "brain.head.profile")
                Spacer()
                Label(TomatoStore.formatStats(store.todayStats.breakSeconds), systemImage: "cup.and.saucer")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Divider()
            HStack {
                Text(store.continueAfterReminder ? "到时继续计时，暂停后手动结束本阶段" : "计时结束后会等待你手动开始下一阶段")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("详细统计") { showStatisticsWindow() }
                Button("退出") { store.terminateApplication() }
            }
        }
        .padding(18)
        .frame(width: 390)
    }

    private func showStatisticsWindow() {
        if let onShowStatistics { onShowStatistics(); return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "statistics")

        // SwiftUI creates the secondary window on the next run-loop pass.
        // Raise that window explicitly because this menu bar app uses accessory activation policy.
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            guard let statisticsWindow = NSApplication.shared.windows.first(where: {
                $0.title == "番茄钟统计"
            }) else { return }
            statisticsWindow.makeKeyAndOrderFront(nil)
            statisticsWindow.orderFrontRegardless()
        }
    }

    private func durationInput(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            TextField("分钟", value: value, formatter: Self.minuteFormatter(range: range))
                .frame(width: 58)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
            Text("分钟")
                .foregroundStyle(.secondary)
            Stepper("调整分钟", value: value, in: range)
                .labelsHidden()
        }
        .frame(width: 165, alignment: .trailing)
    }

    private static func minuteFormatter(range: ClosedRange<Int>) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = NSNumber(value: range.lowerBound)
        formatter.maximum = NSNumber(value: range.upperBound)
        formatter.generatesDecimalNumbers = false
        return formatter
    }
}
