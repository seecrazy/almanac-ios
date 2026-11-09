import Foundation

public struct ScheduleWidgetEventItem: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let calendarTitle: String
    /// RGBA 0–1；日历颜色缺失时为 nil，由 Widget 端回退主题色。
    public let colorRGBA: [Double]?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        calendarTitle: String,
        colorRGBA: [Double]?
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.calendarTitle = calendarTitle
        self.colorRGBA = colorRGBA
    }
}

public struct ScheduleWidgetSnapshot: Codable, Hashable, Sendable {
    public static let version = 1
    public static let maximumCount = 6

    public let version: Int
    public let generatedAt: Date
    /// 快照覆盖的当天零点。
    public let day: Date
    public let events: [ScheduleWidgetEventItem]

    public init(generatedAt: Date, day: Date, events: [ScheduleWidgetEventItem]) {
        self.version = Self.version
        self.generatedAt = generatedAt
        self.day = day
        self.events = Array(events.prefix(Self.maximumCount))
    }
}

public enum ScheduleWidgetSnapshotStorage {
    public static let appGroupIdentifier = MilestoneSnapshotStorage.appGroupIdentifier
    public static let fileName = "schedule-widget-snapshot.json"
}

public enum ScheduleWidgetSnapshotBuilder {
    /// 取某天可见日程：与当天有重叠即算，全天在前、其余按开始时间升序，最多 6 条。
    public static func make(
        items: [ScheduleWidgetEventItem],
        for day: Date,
        generatedAt: Date,
        calendar: Calendar = .current
    ) -> ScheduleWidgetSnapshot {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        let onDay = items.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
        let sorted = onDay.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            return lhs.id < rhs.id
        }

        return ScheduleWidgetSnapshot(
            generatedAt: generatedAt,
            day: dayStart,
            events: sorted
        )
    }
}
