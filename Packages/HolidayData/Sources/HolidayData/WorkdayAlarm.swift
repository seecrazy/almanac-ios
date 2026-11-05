import Foundation

public struct WorkdayAlarm: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var time: Date
    public var soundID: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        time: Date,
        soundID: String = "default",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.time = time
        self.soundID = soundID
        self.isEnabled = isEnabled
    }
}

public struct WorkdayAlarmOccurrence: Hashable {
    public let alarm: WorkdayAlarm
    public let plan: WorkdayPlan
    public let fireDate: Date
}

public enum WorkdayAlarmPlanner {
    public static let maximumAlarmCount = 8

    public static func occurrences(
        alarms: [WorkdayAlarm],
        template: WorkdayTemplate,
        holidays: HolidayStore,
        from reference: Date,
        days: Int = WorkdayResolver.maximumPlanDays,
        calendar: Calendar = .current
    ) -> [WorkdayAlarmOccurrence] {
        let plans = WorkdayResolver.plan(
            from: reference,
            days: days,
            template: template,
            holidays: holidays
        )

        return Array(alarms.prefix(maximumAlarmCount))
            .filter(\.isEnabled)
            .flatMap { alarm -> [WorkdayAlarmOccurrence] in
                plans.compactMap { plan in
                    guard plan.shouldRing,
                          let fireDate = fireDate(on: plan, time: alarm.time, calendar: calendar),
                          fireDate > reference else {
                        return nil
                    }
                    return WorkdayAlarmOccurrence(
                        alarm: alarm,
                        plan: plan,
                        fireDate: fireDate
                    )
                }
            }
            .sorted {
                if $0.fireDate != $1.fireDate {
                    return $0.fireDate < $1.fireDate
                }
                return $0.alarm.id.uuidString < $1.alarm.id.uuidString
            }
    }

    public static func fireDate(
        on plan: WorkdayPlan,
        time: Date,
        calendar: Calendar
    ) -> Date? {
        var holidayCalendar = calendar
        holidayCalendar.timeZone = LunarCalendarShanghai.timezone
        let dateComponents = holidayCalendar.dateComponents(
            [.year, .month, .day],
            from: plan.date
        )
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components)
    }
}
