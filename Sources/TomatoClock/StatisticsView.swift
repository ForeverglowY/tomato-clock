import Charts
import SwiftUI

struct StatisticsView: View {
    @ObservedObject var store: TomatoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            rangeControls
            summaryCards
            chart
            sessionTable
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 600)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("专注统计").font(.title2.bold())
                Text("每天的专注与休息分布，以及每一段实际计时记录")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var rangeControls: some View {
        HStack(spacing: 10) {
            Button("今天") { store.selectStatisticsRange(days: 1) }
            Button("近 7 天") { store.selectStatisticsRange(days: 7) }
            Button("近 30 天") { store.selectStatisticsRange(days: 30) }
            Divider().frame(height: 22)
            DatePicker(
                "从",
                selection: Binding(get: { store.statisticsStartDate }, set: store.setStatisticsStartDate),
                displayedComponents: .date
            )
            .fixedSize()
            DatePicker(
                "到",
                selection: Binding(get: { store.statisticsEndDate }, set: store.setStatisticsEndDate),
                displayedComponents: .date
            )
            .fixedSize()
            Spacer()
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "专注总时长",
                value: TomatoStore.formatStats(store.filteredTotals.focusSeconds),
                icon: "brain.head.profile",
                color: .red
            )
            summaryCard(
                title: "休息总时长",
                value: TomatoStore.formatStats(store.filteredTotals.breakSeconds),
                icon: "cup.and.saucer.fill",
                color: .green
            )
            summaryCard(
                title: "计时段数",
                value: "\(store.filteredSessionRecords.count) 段",
                icon: "list.bullet.rectangle",
                color: .blue
            )
            goalSummaryCard
        }
    }

    private var goalSummaryCard: some View {
        HStack(spacing: 10) {
            FocusGoalRing(progress: store.filteredGoalProgress, size: 38, lineWidth: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text("目标达成").font(.caption).foregroundStyle(.secondary)
                Text("\(store.filteredAchievedDayCount) / \(store.filteredDayCount) 天")
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).monospacedDigit()
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日时长").font(.headline)
            Chart {
                ForEach(store.dailyStatBars) { bar in
                    BarMark(
                        x: .value("日期", TomatoStore.formatChartDay(bar.date)),
                        y: .value("分钟", bar.seconds / 60)
                    )
                    .foregroundStyle(by: .value("类型", bar.kind == .focus ? "专注" : "休息"))
                    .position(by: .value("类型", bar.kind.rawValue))
                }
                RuleMark(y: .value("每日目标", store.dailyFocusGoalMinutes))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标 \(store.dailyFocusGoalMinutes) 分钟")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
            }
            .chartForegroundStyleScale(["专注": Color.red, "休息": Color.green])
            .chartXAxis {
                AxisMarks(values: store.chartAxisLabels) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxisLabel("分钟")
            .frame(height: 190)
        }
    }

    private var sessionTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间段明细").font(.headline)
            tableHeader
            if store.filteredSessionRecords.isEmpty {
                ContentUnavailableView(
                    "暂无时间段记录",
                    systemImage: "clock.badge.questionmark",
                    description: Text("新版本开始计时后，每次暂停或完成都会记录在这里。")
                )
                .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredSessionRecords) { record in
                            sessionRow(record)
                            Divider()
                        }
                    }
                }
                .frame(minHeight: 120)
            }
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("日期").frame(width: 110, alignment: .leading)
            Text("类型").frame(width: 70, alignment: .leading)
            Text("开始").frame(width: 90, alignment: .leading)
            Text("结束").frame(width: 90, alignment: .leading)
            Text("时长").frame(width: 110, alignment: .leading)
            Spacer()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
    }

    private func sessionRow(_ record: TomatoStore.SessionRecord) -> some View {
        HStack {
            Text(record.startDate, format: .dateTime.year().month().day())
                .frame(width: 110, alignment: .leading)
            Label(
                record.kind == .focus ? "专注" : "休息",
                systemImage: record.kind == .focus ? "brain.head.profile" : "cup.and.saucer"
            )
            .foregroundStyle(record.kind == .focus ? Color.red : Color.green)
            .frame(width: 70, alignment: .leading)
            Text(record.startDate, format: .dateTime.hour().minute().second())
                .frame(width: 90, alignment: .leading)
            Text(record.endDate, format: .dateTime.hour().minute().second())
                .frame(width: 90, alignment: .leading)
            Text(TomatoStore.formatPreciseDuration(record.duration))
                .frame(width: 110, alignment: .leading)
            Spacer()
        }
        .font(.callout)
        .monospacedDigit()
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }
}
