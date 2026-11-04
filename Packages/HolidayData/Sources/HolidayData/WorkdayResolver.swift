import Foundation

public enum WorkdayTemplateKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case standardFiveDay
    case singleRestDay
    case sixDayWeek
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standardFiveDay: return "标准双休"
        case .singleRestDay: return "单休"
        case .sixDayWeek: return "六天工作"
        case .custom: return "自定义"
        }
    }
}

public struct WorkdayTemplate: Codable, Hashable {
    public var kind: WorkdayTemplateKind
    public var customWeekdays: Set<Int>

    public init(
        kind: WorkdayTemplateKind,
        customWeekdays: Set<Int> = []
    ) {
        self.kind = kind
        self.customWeekdays = customWeekdays
    }

    public static let standard = WorkdayTemplate(
        kind: .standardFiveDay,
        customWeekdays: Set(2...6)
    )

    public static let singleRest = WorkdayTemplate(
        kind: .singleRestDay,
        customWeekdays: Set(2...7)
    )

    public static let sixDay = WorkdayTemplate(
        kind: .sixDayWeek,
        customWeekdays: Set(2...7)
    )

    public func isWorkday(weekday: Int) -> Bool {
        switch kind {
        case .standardFiveDay:
            return (2...6).contains(weekday)
        case .singleRestDay, .sixDayWeek:
            return (2...7).contains(weekday)
        case .custom:
            return customWeekdays.contains(weekday)
        }
    }
}

public enum HolidayAdjustment: Hashable {
    case restDay(name: String)
    case workday(name: String)

    public var name: String {
        switch self {
        case .restDay(let name), .workday(let name):
            return name
        }
    }
}

public struct WorkdayPlan: Hashable {
    public let date: Date
    public let baseIsWorkday: Bool
    public let holidayAdjustment: HolidayAdjustment?
    public let shouldRing: Bool
    public let reason: String
    public let holidayCoverage: HolidayCoverage
}

public enum WorkdayResolver {
    public static let maximumPlanDays = 60

    public static func weekdayName(for weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "" }
        return weekdayNames[weekday - 1]
    }

    public static func plan(
        from date: Date,
        days: Int,
        template: WorkdayTemplate,
        holidays: HolidayStore,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [WorkdayPlan] {
        var shanghaiCalendar = calendar
        shanghaiCalendar.timeZone = LunarCalendarShanghai.timezone
        let count = min(max(days, 0), maximumPlanDays)
        let start = shanghaiCalendar.startOfDay(for: date)

        return (0..<count).compactMap { offset in
            shanghaiCalendar.date(
                byAdding: .day,
                value: offset,
                to: start
            ).map { day in
                planDay(
                    day,
                    template: template,
                    holidays: holidays,
                    calendar: shanghaiCalendar
                )
            }
        }
    }

    public static func planDay(
        _ date: Date,
        template: WorkdayTemplate,
        holidays: HolidayStore,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> WorkdayPlan {
        var shanghaiCalendar = calendar
        shanghaiCalendar.timeZone = LunarCalendarShanghai.timezone
        let weekday = shanghaiCalendar.component(.weekday, from: date)
        let baseIsWorkday = template.isWorkday(weekday: weekday)
        let coverage = holidays.coverage(for: date)

        let adjustment: HolidayAdjustment?
        switch holidays.effect(for: date) {
        case .restDay(let name):
            adjustment = .restDay(name: name)
        case .workday(let name):
            adjustment = .workday(name: name)
        case nil:
            adjustment = nil
        }

        let shouldRing: Bool
        let reason: String
        switch adjustment {
        case .restDay:
            shouldRing = false
            reason = "法定休息日，闹钟关闭"
        case .workday:
            shouldRing = true
            reason = "调休补班日，闹钟开启"
        case nil:
            shouldRing = baseIsWorkday
            reason = baseReason(
                weekday: weekday,
                isWorkday: baseIsWorkday,
                coverage: coverage
            )
        }

        return WorkdayPlan(
            date: shanghaiCalendar.startOfDay(for: date),
            baseIsWorkday: baseIsWorkday,
            holidayAdjustment: adjustment,
            shouldRing: shouldRing,
            reason: reason,
            holidayCoverage: coverage
        )
    }

    private static func baseReason(
        weekday: Int,
        isWorkday: Bool,
        coverage: HolidayCoverage
    ) -> String {
        if coverage == .unknown || coverage == .yearNotLoaded {
            return "节假日数据未覆盖，按模板执行"
        }
        let weekdayName = weekdayNames[weekday - 1]
        return isWorkday ? "\(weekdayName)，闹钟开启" : "\(weekdayName)，闹钟关闭"
    }

    private static let weekdayNames = [
        "周日", "周一", "周二", "周三", "周四", "周五", "周六"
    ]
}
