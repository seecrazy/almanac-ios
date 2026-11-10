import CalendarAnalysis
import SwiftUI

/// 年度回顾页：选年份 → 拉取该年日程 → 本地统计 → 卡片 + 文本分享。
struct YearReportView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eventService: EventStoreService
    @EnvironmentObject private var milestoneStore: MilestoneStore

    @State private var year: Int
    @State private var report: YearReport?
    @State private var isLoading = false
    @State private var shareText: String?

    init(initialYear: Int = Calendar.current.component(.year, from: Date())) {
        _year = State(initialValue: initialYear)
    }

    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 2)...current).reversed()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("年份", selection: $year) {
                        ForEach(availableYears, id: \.self) { item in
                            Text("\(String(item)) 年").tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if eventService.accessState == .denied {
                        deniedCard
                    } else if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else if let report {
                        reportCards(report)
                    } else {
                        Text("该年暂无日程数据")
                            .font(.system(size: 13))
                            .foregroundColor(palette.secondary)
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("年度回顾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let report {
                        Button("分享") { shareText = report.summaryText }
                    }
                }
            }
            .task(id: year) { await load() }
            .sheet(item: $shareText) { text in
                ActivityShareSheet(items: [text])
                    .ignoresSafeArea()
            }
        }
    }

    private var deniedCard: some View {
        VStack(spacing: 10) {
            Text("无法读取系统日历，年度回顾需要日历权限。")
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
            OpenSettingsLink()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    @ViewBuilder
    private func reportCards(_ report: YearReport) -> some View {
        statRow(
            title: "日程",
            value: "\(report.timedEventCount + report.allDayEventCount)",
            subtitle: "全天 \(report.allDayEventCount) · 周末 \(report.weekendEventCount)"
        )
        statRow(
            title: "时长",
            value: String(format: "%.1f 小时", report.totalHours),
            subtitle: report.longestEventTitle.map { "最长「\($0)」\(String(format: "%.1f", report.longestEventHours)) 小时" }
        )
        if let month = report.busiestMonth, report.busiestMonthCount > 0 {
            statRow(title: "最忙的月份", value: "\(month) 月", subtitle: "\(report.busiestMonthCount) 项日程")
        }
        if let weekday = report.busiestWeekday, report.busiestWeekdayCount > 0 {
            statRow(title: "最常安排", value: weekday, subtitle: "\(report.busiestWeekdayCount) 项")
        }
        if let calendar = report.topCalendarTitle, report.topCalendarCount > 0 {
            statRow(title: "最常用日历", value: calendar, subtitle: "\(report.topCalendarCount) 项")
        }
        statRow(
            title: "里程碑",
            value: "\(report.pastMilestones)",
            subtitle: "已完成 · 进行中 \(report.upcomingMilestones)"
        )

        VStack(alignment: .leading, spacing: 8) {
            Text("月度分布")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(palette.ink)
            let maxCount = max(1, report.monthCounts.max() ?? 1)
            VStack(spacing: 5) {
                ForEach(1...12, id: \.self) { month in
                    HStack(spacing: 8) {
                        Text("\(month)月")
                            .font(.system(size: 11))
                            .foregroundColor(palette.secondary)
                            .frame(width: 32, alignment: .leading)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(palette.accent.opacity(month == report.busiestMonth ? 1 : 0.55))
                                .frame(width: max(3, proxy.size.width * CGFloat(report.monthCounts[month - 1]) / CGFloat(maxCount)))
                        }
                        Text("\(report.monthCounts[month - 1])")
                            .font(.system(size: 11))
                            .foregroundColor(palette.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }

    private func statRow(title: String, value: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(palette.secondary.opacity(0.8))
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }

    private func load() async {
        guard eventService.accessState == .granted || eventService.accessState == .notDetermined else {
            report = nil
            return
        }
        await eventService.requestAccessIfNeeded()

        isLoading = true
        defer { isLoading = false }

        var components = DateComponents(year: year, month: 1, day: 1)
        let start = Calendar.current.date(from: components)!
        components.year = year + 1
        let end = Calendar.current.date(from: components)!
        await eventService.loadEvents(from: start, to: end)

        let reference = Date()
        let reportEvents = eventService.events.map { event in
            YearReportEvent(
                id: event.id,
                title: event.title,
                calendarTitle: event.calendarTitle,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }
        let milestones = milestoneStore.sortedMilestones(at: reference)
        report = YearReportBuilder.build(
            year: year,
            events: reportEvents,
            upcomingMilestones: milestones.filter { $0.effectiveSortDate >= reference }.count,
            pastMilestones: milestones.filter { $0.effectiveSortDate < reference }.count
        )
    }
}

extension String: Identifiable {
    public var id: String { self }
}
