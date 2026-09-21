import SwiftUI

struct GoalCalendarView: View {
    @ObservedObject var store: TomatoStore

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
    }

    private func dayCell(_ day: TomatoStore.GoalDay) -> some View {
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
                showsCenterIcon: false
            )
            .opacity(day.focusSeconds > 0 ? 1 : 0.32)
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
        .help("\(TomatoStore.formatChartDay(day.date))：专注 \(TomatoStore.formatPreciseDuration(day.focusSeconds))，目标 \(store.dailyFocusGoalMinutes) 分钟")
    }
}
