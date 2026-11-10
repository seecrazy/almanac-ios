import Foundation

/// 年度回顾的输入事件（App 侧由 CalendarEvent 映射，保持包零 EventKit 依赖）。
public struct YearReportEvent: Hashable, Sendable {
    public let id: String
    public let title: String
    public let calendarTitle: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool

    public init(
        id: String,
        title: String,
        calendarTitle: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) {
        self.id = id
        self.title = title
        self.calendarTitle = calendarTitle
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
    }
}

public struct YearReport: Hashable, Sendable {
    public let year: Int
    public let timedEventCount: Int
    public let allDayEventCount: Int
    /// 时刻事件时长合计（跨年按当年区间裁剪），小时。
    public let totalHours: Double
    public let longestEventTitle: String?
    public let longestEventHours: Double
    public let busiestMonth: Int?
    public let busiestMonthCount: Int
    public let busiestWeekday: String?
    public let busiestWeekdayCount: Int
    public let monthCounts: [Int]
    public let topCalendarTitle: String?
    public let topCalendarCount: Int
    public let weekendEventCount: Int
    public let upcomingMilestones: Int
    public let pastMilestones: Int

    public var summaryText: String {
        var lines = [
            "【\(year) 年度回顾 · 宜历】",
            "🗓 日程 \(timedEventCount + allDayEventCount) 项（全天 \(allDayEventCount)，周末 \(weekendEventCount)）",
            "⏱ 日程时长合计 \(String(format: "%.1f", totalHours)) 小时"
        ]
        if let longest = longestEventTitle, longestEventHours > 0 {
            lines.append("🌟 最长日程「\(longest)」\(String(format: "%.1f", longestEventHours)) 小时")
        }
        if let month = busiestMonth, busiestMonthCount > 0 {
            lines.append("📅 最忙的月份：\(month) 月（\(busiestMonthCount) 项）")
        }
        if let weekday = busiestWeekday, busiestWeekdayCount > 0 {
            lines.append("📆 最常安排的星期：\(weekday)（\(busiestWeekdayCount) 项）")
        }
        if let calendar = topCalendarTitle, topCalendarCount > 0 {
            lines.append("🎨 用得最多的日历「\(calendar)」\(topCalendarCount) 项")
        }
        lines.append("⏳ 里程碑：已完成 \(pastMilestones) · 进行中 \(upcomingMilestones)")
        return lines.joined(separator: "\n")
    }
}

public enum YearReportBuilder {
    public static func build(
        year: Int,
        events: [YearReportEvent],
        upcomingMilestones: Int = 0,
        pastMilestones: Int = 0,
        calendar: Calendar = .current
    ) -> YearReport {
        var yearStartComponents = DateComponents(year: year, month: 1, day: 1)
        let yearStart = calendar.date(from: yearStartComponents)!
        yearStartComponents.year = year + 1
        let yearEnd = calendar.date(from: yearStartComponents)!
        let yearInterval = DateInterval(start: yearStart, end: yearEnd)

        // 只统计与该年有重叠的事件。
        let onYear = events.filter { $0.startDate < yearEnd && $0.endDate > yearStart }

        let timed = onYear.filter { !$0.isAllDay }
        let allDay = onYear.filter { $0.isAllDay }

        var totalSeconds: TimeInterval = 0
        var longestSeconds: TimeInterval = 0
        var longestTitle: String?
        for event in timed {
            let start = max(event.startDate, yearStart)
            let end = min(event.endDate, yearEnd)
            let duration = max(0, end.timeIntervalSince(start))
            totalSeconds += duration
            if duration > longestSeconds {
                longestSeconds = duration
                longestTitle = event.title
            }
        }

        var monthCounts = Array(repeating: 0, count: 12)
        var weekdayCounts = Array(repeating: 0, count: 7)
        var weekendCount = 0
        var calendarCounts: [String: Int] = [:]
        for event in onYear {
            let month = calendar.component(.month, from: max(event.startDate, yearStart))
            monthCounts[month - 1] += 1
            let weekday = calendar.component(.weekday, from: max(event.startDate, yearStart))
            weekdayCounts[weekday - 1] += 1
            if weekday == 1 || weekday == 7 { weekendCount += 1 }
            calendarCounts[event.calendarTitle, default: 0] += 1
        }

        let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let bestMonthIndex = monthCounts.indices.max { monthCounts[$0] < monthCounts[$1] }
        let bestWeekdayIndex = weekdayCounts.indices.max { weekdayCounts[$0] < weekdayCounts[$1] }
        let topCalendar = calendarCounts.max { $0.value < $1.value }

        return YearReport(
            year: year,
            timedEventCount: timed.count,
            allDayEventCount: allDay.count,
            totalHours: totalSeconds / 3600,
            longestEventTitle: longestTitle,
            longestEventHours: longestSeconds / 3600,
            busiestMonth: monthCounts[bestMonthIndex ?? 0] > 0 ? (bestMonthIndex ?? 0) + 1 : nil,
            busiestMonthCount: monthCounts[bestMonthIndex ?? 0],
            busiestWeekday: weekdayCounts[bestWeekdayIndex ?? 0] > 0 ? weekdayNames[bestWeekdayIndex ?? 0] : nil,
            busiestWeekdayCount: weekdayCounts[bestWeekdayIndex ?? 0],
            monthCounts: monthCounts,
            topCalendarTitle: topCalendar?.value == 0 ? nil : topCalendar?.key,
            topCalendarCount: topCalendar?.value ?? 0,
            weekendEventCount: weekendCount,
            upcomingMilestones: upcomingMilestones,
            pastMilestones: pastMilestones
        )
    }
}
