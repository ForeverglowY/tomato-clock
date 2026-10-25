import SwiftUI

struct GoalCalendarView: View {
    @ObservedObject var store: TomatoStore
    @Binding var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private let weekdayNames = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdayNames, id: \.self) { name in
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(store.goalCalendarMonths) { month in
                        monthSection(month)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(height: 240)
    }

    private func monthSection(_ month: TomatoStore.GoalMonth) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TomatoStore.formatChartMonth(month.firstDay))
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<month.leadingEmptyDays, id: \.self) { _ in
                    Color.clear.frame(height: 66)
                }
                ForEach(month.days) { day in
                    dayCell(day)
                }
            }
        }
        .padding(12)
        .adaptiveGlassCard(cornerRadius: 16, tint: .orange.opacity(0.05))
    }

    private func dayCell(_ day: TomatoStore.GoalDay) -> some View {
        Button {
            selectedDate = day.date
        } label: {
        VStack(spacing: 4) {
            Text(day.date, format: .dateTime.day())
                .font(.caption.weight(Calendar.current.isDateInToday(day.date) ? .bold : .regular))
                .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.white : Color.primary)
                .frame(width: 24, height: 20)
                .background(
                    Calendar.current.isDateInToday(day.date) ? Color.red : Color.clear,
                    in: Circle()
                )

            FocusGoalRing(
                progress: day.progress,
                size: 38,
                lineWidth: 5,
                showsCenterIcon: day.achieved
            )
            .opacity(day.focusSeconds > 0 ? 1 : 0.32)
            .overlay {
                HoverTrackingView(text: daySummary(day))
                    .frame(width: 44, height: 44)
            }
            .overlay(alignment: .topTrailing) {
                if day.achieved {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .padding(4)
        .background(selectedDate == day.date ? Color.accentColor.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(daySummary(day))
        .accessibilityHint("查看当天专注和休息明细")
        .accessibilityAddTraits(selectedDate == day.date ? .isSelected : [])
    }

    private func daySummary(_ day: TomatoStore.GoalDay) -> String {
        let percentage = Int((day.focusSeconds / max(day.goalSeconds, 1) * 100).rounded())
        return "\(day.date.formatted(.dateTime.year().month().day()))\n专注 \(TomatoStore.formatPreciseDuration(day.focusSeconds))\n目标 \(store.dailyFocusGoalMinutes) 分钟 · 完成 \(percentage)%"
    }
}
