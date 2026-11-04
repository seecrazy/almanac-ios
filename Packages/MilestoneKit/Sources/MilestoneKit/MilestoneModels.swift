import Foundation

public enum MilestoneReminderKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case sevenDaysAtNine
    case oneDayAtNine
    case sameDayAtNine
    case sameDayAtTarget

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sevenDaysAtNine: return "提前 7 天（09:00）"
        case .oneDayAtNine: return "提前 1 天（09:00）"
        case .sameDayAtNine: return "当天 09:00"
        case .sameDayAtTarget: return "目标时间"
        }
    }
}

public struct MilestoneReminder: Codable, Hashable, Identifiable {
    public let kind: MilestoneReminderKind
    public var isEnabled: Bool

    public var id: MilestoneReminderKind { kind }

    public init(kind: MilestoneReminderKind, isEnabled: Bool = true) {
        self.kind = kind
        self.isEnabled = isEnabled
    }
}

public struct MilestoneSnapshotItem: Codable, Hashable, Identifiable {
    public let id: UUID
    public let title: String
    public let targetDate: Date
    public let isAllDay: Bool
    public let category: String

    public init(
        id: UUID,
        title: String,
        targetDate: Date,
        isAllDay: Bool,
        category: String
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.isAllDay = isAllDay
        self.category = category
    }
}

public struct MilestoneSnapshot: Codable, Hashable {
    public static let version = 1
    public static let maximumCount = 8

    public let version: Int
    public let generatedAt: Date
    public let milestones: [MilestoneSnapshotItem]

    public init(generatedAt: Date, milestones: [MilestoneSnapshotItem]) {
        self.version = Self.version
        self.generatedAt = generatedAt
        self.milestones = Array(milestones.prefix(Self.maximumCount))
    }
}

public enum MilestoneSnapshotStorage {
    public static let appGroupIdentifier = "group.com.yili.almanac.shared"
    public static let fileName = "milestone-widget-snapshot.json"
}

public enum MilestoneSnapshotBuilder {
    public static func make(
        milestones: [MilestoneSnapshotItem],
        generatedAt: Date,
        calendar: Calendar = .current
    ) -> MilestoneSnapshot {
        let startOfToday = calendar.startOfDay(for: generatedAt)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? generatedAt
        let upcoming = milestones
            .filter { item in
                item.isAllDay
                    ? calendar.startOfDay(for: item.targetDate) >= startOfToday
                    : item.targetDate >= generatedAt
            }
            .sorted { lhs, rhs in
                effectiveDate(of: lhs, calendar: calendar) <
                effectiveDate(of: rhs, calendar: calendar)
            }

        let withinSevenDays = upcoming.filter { item in
            effectiveDate(of: item, calendar: calendar) < weekEnd
        }
        let later = upcoming.filter { item in
            effectiveDate(of: item, calendar: calendar) >= weekEnd
        }

        return MilestoneSnapshot(
            generatedAt: generatedAt,
            milestones: withinSevenDays + later
        )
    }

    private static func effectiveDate(
        of item: MilestoneSnapshotItem,
        calendar: Calendar
    ) -> Date {
        item.isAllDay ? calendar.startOfDay(for: item.targetDate) : item.targetDate
    }
}
