import Foundation

public struct MilestoneNotificationRequest: Hashable {
    public let identifier: String
    public let fireDate: Date
    public let title: String
    public let subtitle: String
    public let body: String

    public init(
        identifier: String,
        fireDate: Date,
        title: String,
        subtitle: String,
        body: String
    ) {
        self.identifier = identifier
        self.fireDate = fireDate
        self.title = title
        self.subtitle = subtitle
        self.body = body
    }
}

public enum MilestoneNotificationPlanner {
    public static let maximumSchedulingWindow: TimeInterval = 60 * 24 * 60 * 60

    public static func requests(
        milestoneID: UUID,
        title: String,
        targetDate: Date,
        isAllDay: Bool,
        reminders: [MilestoneReminder],
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [MilestoneNotificationRequest] {
        let enabledKinds = reminders
            .filter(\.isEnabled)
            .map(\.kind)
            .filter { MilestoneReminderKind.allCases.contains($0) }

        let normalizedTarget = isAllDay
            ? calendar.startOfDay(for: targetDate)
            : targetDate
        let latestDate = referenceDate.addingTimeInterval(maximumSchedulingWindow)

        return MilestoneReminderKind.allCases.compactMap { kind in
            guard enabledKinds.contains(kind),
                  let fireDate = fireDate(
                      kind: kind,
                      targetDate: normalizedTarget,
                      calendar: calendar
                  ),
                  fireDate > referenceDate,
                  fireDate <= latestDate else {
                return nil
            }

            return MilestoneNotificationRequest(
                identifier: identifier(milestoneID: milestoneID, kind: kind),
                fireDate: fireDate,
                title: "倒计时提醒",
                subtitle: title,
                body: body(kind: kind, title: title)
            )
        }
    }

    public static func identifier(milestoneID: UUID, kind: MilestoneReminderKind) -> String {
        "milestone.\(milestoneID.uuidString).\(kind.rawValue)"
    }

    public static func identifierPrefix(milestoneID: UUID) -> String {
        "milestone.\(milestoneID.uuidString)."
    }

    private static func fireDate(
        kind: MilestoneReminderKind,
        targetDate: Date,
        calendar: Calendar
    ) -> Date? {
        switch kind {
        case .sevenDaysAtNine:
            return dateOnDay(
                addingDays: -7,
                to: targetDate,
                calendar: calendar
            )
        case .oneDayAtNine:
            return dateOnDay(
                addingDays: -1,
                to: targetDate,
                calendar: calendar
            )
        case .sameDayAtNine:
            return dateOnDay(
                addingDays: 0,
                to: targetDate,
                calendar: calendar
            )
        case .sameDayAtTarget:
            return targetDate
        }
    }

    private static func dateOnDay(
        addingDays days: Int,
        to targetDate: Date,
        calendar: Calendar
    ) -> Date? {
        let targetDay = calendar.startOfDay(for: targetDate)
        let reminderDay = calendar.date(byAdding: .day, value: days, to: targetDay) ?? targetDay
        return calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: reminderDay
        )
    }

    private static func body(kind: MilestoneReminderKind, title: String) -> String {
        switch kind {
        case .sevenDaysAtNine: return "距离「\(title)」还有 7 天"
        case .oneDayAtNine: return "明天是「\(title)」"
        case .sameDayAtNine: return "今天是「\(title)」"
        case .sameDayAtTarget: return "「\(title)」时间到了"
        }
    }
}
