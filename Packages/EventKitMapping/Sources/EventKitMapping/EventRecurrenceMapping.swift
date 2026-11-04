import EventKit
import Foundation

public enum EventRecurrenceMode: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
    case preserveExisting

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .biweekly: return "每两周"
        case .monthly: return "每月"
        case .yearly: return "每年"
        case .preserveExisting: return "保留现有规则"
        }
    }

    public static func formModes(isProtected: Bool) -> [EventRecurrenceMode] {
        isProtected ? [.preserveExisting] : [.none, .daily, .weekly, .biweekly, .monthly, .yearly]
    }
}

public enum EventRecurrenceEndMode: String, CaseIterable, Identifiable {
    case never
    case onDate
    case afterCount

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .never: return "一直重复"
        case .onDate: return "到日期重复"
        case .afterCount: return "按次数重复"
        }
    }
}

public enum EventMonthlyRecurrenceRule: Hashable, Identifiable {
    case dayOfMonth(Int)
    case nthWeekday(week: Int, weekday: Int)

    public var id: String {
        switch self {
        case .dayOfMonth(let day): return "day-\(day)"
        case .nthWeekday(let week, let weekday): return "nth-\(week)-\(weekday)"
        }
    }

    public var title: String {
        let weekdayNames = [1: "周日", 2: "周一", 3: "周二", 4: "周三", 5: "周四", 6: "周五", 7: "周六"]
        switch self {
        case .dayOfMonth(let day):
            return "每月 \(day) 日"
        case .nthWeekday(let week, let weekday):
            return "每月第 \(week) 个\(weekdayNames[weekday] ?? "")"
        }
    }
}

public enum EventEditScope: String, CaseIterable, Identifiable {
    case thisEvent
    case futureEvents
    case wholeSeries

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .thisEvent: return "仅此发生"
        case .futureEvents: return "此次及未来"
        case .wholeSeries: return "整个系列"
        }
    }
}

public struct EventRecurrenceDraft: Hashable {
    public var mode: EventRecurrenceMode
    public var interval: Int
    public var weekdays: Set<Int>
    public var monthlyRule: EventMonthlyRecurrenceRule
    public var endMode: EventRecurrenceEndMode
    public var endDate: Date
    public var occurrenceCount: Int

    public init(
        mode: EventRecurrenceMode,
        interval: Int = 1,
        weekdays: Set<Int>? = nil,
        monthlyRule: EventMonthlyRecurrenceRule? = nil,
        endMode: EventRecurrenceEndMode = .never,
        endDate: Date,
        occurrenceCount: Int = 1
    ) {
        self.mode = mode
        self.interval = max(1, interval)
        self.weekdays = weekdays ?? []
        self.monthlyRule = monthlyRule ?? .dayOfMonth(Calendar.current.component(.day, from: endDate))
        self.endMode = endMode
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
    }

    public init(startDate: Date) {
        let fallbackDate = Calendar.current.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        let weekday = Calendar.current.component(.weekday, from: startDate)
        self.init(
            mode: .none,
            weekdays: [weekday],
            monthlyRule: .dayOfMonth(Calendar.current.component(.day, from: startDate)),
            endMode: .never,
            endDate: fallbackDate
        )
    }

    public init?(rules: [EKRecurrenceRule]?, startDate: Date) {
        guard let rules, rules.count == 1, let rule = rules.first else {
            self = EventRecurrenceDraft(startDate: startDate)
            return
        }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.weekday, .day, .month], from: startDate)
        let weekdayRules = rule.daysOfTheWeek ?? []
        let dayRules = (rule.daysOfTheMonth ?? []).compactMap { $0.intValue }
        let monthRules = (rule.monthsOfTheYear ?? []).compactMap { $0.intValue }
        let hasUnsupportedParts = !(rule.setPositions ?? []).isEmpty
            || !(rule.daysOfTheYear ?? []).isEmpty
            || !(rule.weeksOfTheYear ?? []).isEmpty
            || dayRules.contains(where: { $0 < 0 })
            || weekdayRules.contains(where: { $0.weekNumber < 0 })

        guard !hasUnsupportedParts else {
            self = EventRecurrenceDraft.preserved()
            return
        }

        var mode: EventRecurrenceMode
        let interval = max(1, rule.interval)

        switch rule.frequency {
        case .daily where (1...999).contains(rule.interval):
            mode = .daily
            guard weekdayRules.isEmpty, dayRules.isEmpty, monthRules.isEmpty else {
                self = EventRecurrenceDraft.preserved()
                return
            }
        case .weekly where rule.interval == 1:
            mode = .weekly
        case .weekly where rule.interval == 2:
            mode = .biweekly
        case .monthly where rule.interval == 1:
            mode = .monthly
        case .yearly where rule.interval == 1:
            mode = .yearly
        default:
            self = EventRecurrenceDraft.preserved()
            return
        }

        var weekdays = Set<Int>()
        var monthlyRule: EventMonthlyRecurrenceRule?

        switch mode {
        case .weekly, .biweekly:
            guard dayRules.isEmpty, monthRules.isEmpty,
                  weekdayRules.allSatisfy({ $0.weekNumber == 0 }) else {
                self = EventRecurrenceDraft.preserved()
                return
            }
            weekdays = Set(weekdayRules.map(\.dayOfTheWeek.rawValue))
            if weekdays.isEmpty, let startWeekday = startComponents.weekday {
                weekdays = [startWeekday]
            }
        case .monthly:
            guard monthRules.isEmpty else {
                self = EventRecurrenceDraft.preserved()
                return
            }

            if weekdayRules.isEmpty {
                guard dayRules.isEmpty || dayRules == [startComponents.day] else {
                    self = EventRecurrenceDraft.preserved()
                    return
                }
                monthlyRule = .dayOfMonth(startComponents.day ?? 1)
            } else if weekdayRules.count == 1, dayRules.isEmpty {
                let weekdayRule = weekdayRules[0]
                guard (1...5).contains(weekdayRule.weekNumber) else {
                    self = EventRecurrenceDraft.preserved()
                    return
                }
                monthlyRule = .nthWeekday(
                    week: weekdayRule.weekNumber,
                    weekday: weekdayRule.dayOfTheWeek.rawValue
                )
            } else {
                self = EventRecurrenceDraft.preserved()
                return
            }
        case .yearly:
            guard weekdayRules.isEmpty,
                  (monthRules.isEmpty || monthRules == [startComponents.month]),
                  (dayRules.isEmpty || dayRules == [startComponents.day]) else {
                self = EventRecurrenceDraft.preserved()
                return
            }
        default:
            break
        }

        let recurrenceEnd = rule.recurrenceEnd
        let endMode: EventRecurrenceEndMode
        var endDate = startDate
        var occurrenceCount = 1

        if recurrenceEnd == nil {
            endMode = .never
        } else if let end = recurrenceEnd?.endDate {
            endMode = .onDate
            endDate = calendar.startOfDay(for: end)
        } else if let count = recurrenceEnd?.occurrenceCount {
            endMode = .afterCount
            occurrenceCount = count
        } else {
            self = EventRecurrenceDraft.preserved()
            return
        }

        self.init(
            mode: mode,
            interval: interval,
            weekdays: weekdays,
            monthlyRule: monthlyRule,
            endMode: endMode,
            endDate: endDate,
            occurrenceCount: occurrenceCount
        )
    }

    public static func preserved() -> EventRecurrenceDraft {
        EventRecurrenceDraft(mode: .preserveExisting, endMode: .never, endDate: Date())
    }

    public func canRepresent(startDate: Date) -> Bool {
        if mode == .none || mode == .preserveExisting { return true }
        guard (1...999).contains(interval) else { return false }
        if (mode == .weekly || mode == .biweekly), weekdays.isEmpty { return false }
        if mode == .monthly {
            switch monthlyRule {
            case .dayOfMonth(let day): return (1...31).contains(day)
            case .nthWeekday(let week, let weekday):
                return (1...5).contains(week) && (1...7).contains(weekday)
            }
        }
        if endMode == .afterCount { return occurrenceCount >= 1 }
        if endMode == .onDate {
            return Calendar.current.startOfDay(for: endDate) >= Calendar.current.startOfDay(for: startDate)
        }
        return true
    }

    public func makeRule(startDate: Date) -> EKRecurrenceRule? {
        guard canRepresent(startDate: startDate), mode != .none, mode != .preserveExisting else { return nil }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.weekday, .day, .month], from: startDate)
        let frequency: EKRecurrenceFrequency
        var weekdays: [EKRecurrenceDayOfWeek]?
        var daysOfTheMonth: [NSNumber]?
        var monthsOfTheYear: [NSNumber]?

        switch mode {
        case .daily:
            frequency = .daily
        case .weekly, .biweekly:
            frequency = .weekly
            let selected = self.weekdays.isEmpty ? Set([startComponents.weekday ?? 1]) : self.weekdays
            weekdays = selected
                .compactMap { EKWeekday(rawValue: $0) }
                .map { EKRecurrenceDayOfWeek($0) }
                .sorted { $0.dayOfTheWeek.rawValue < $1.dayOfTheWeek.rawValue }
        case .monthly:
            frequency = .monthly
            switch monthlyRule {
            case .dayOfMonth(let day):
                daysOfTheMonth = [NSNumber(value: day)]
            case .nthWeekday(let week, let weekday):
                guard let recurrenceWeekday = EKWeekday(rawValue: weekday) else { return nil }
                weekdays = [EKRecurrenceDayOfWeek(recurrenceWeekday, weekNumber: week)]
            }
        case .yearly:
            frequency = .yearly
            monthsOfTheYear = [NSNumber(value: startComponents.month ?? 1)]
            daysOfTheMonth = [NSNumber(value: startComponents.day ?? 1)]
        case .none, .preserveExisting:
            return nil
        }

        let end: EKRecurrenceEnd?
        switch endMode {
        case .never:
            end = nil
        case .onDate:
            let selectedDayStart = calendar.startOfDay(for: endDate)
            let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: selectedDayStart)
                ?? selectedDayStart
            end = EKRecurrenceEnd(end: endOfDay)
        case .afterCount:
            end = EKRecurrenceEnd(occurrenceCount: occurrenceCount)
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: weekdays,
            daysOfTheMonth: daysOfTheMonth,
            monthsOfTheYear: monthsOfTheYear,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }

    public func previewOccurrences(
        startDate: Date,
        count: Int = 3,
        calendar: Calendar = .current
    ) -> [Date] {
        guard mode != .none, mode != .preserveExisting, canRepresent(startDate: startDate) else { return [] }
        let maxCount = min(count, endMode == .afterCount ? occurrenceCount : count)
        guard maxCount > 0 else { return [] }
        var result: [Date] = [startDate]
        let clock = calendar.dateComponents([.hour, .minute, .second], from: startDate)

        func at(year: Int, month: Int, day: Int) -> Date? {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = clock.hour
            components.minute = clock.minute
            components.second = clock.second
            return calendar.date(from: components)
        }

        switch mode {
        case .daily:
            while result.count < maxCount {
                guard let next = calendar.date(
                    byAdding: .day,
                    value: interval,
                    to: result[result.count - 1]
                ) else { break }
                if endMode == .onDate, next > endDate { break }
                result.append(next)
            }
        case .weekly, .biweekly:
            var cursor = startDate
            while result.count < maxCount {
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = nextDay
                guard weekdays.contains(calendar.component(.weekday, from: cursor)) else { continue }
                let weekDistance = calendar.dateComponents(
                    [.weekOfYear],
                    from: calendar.startOfWeek(for: startDate),
                    to: calendar.startOfWeek(for: cursor)
                ).weekOfYear ?? 0
                guard weekDistance % interval == 0 else { continue }
                if endMode == .onDate, cursor > endDate { break }
                result.append(cursor)
            }
        case .monthly:
            while result.count < maxCount {
                let period = result.count * interval
                guard let monthDate = calendar.date(
                    byAdding: .month,
                    value: period,
                    to: calendar.startOfMonth(for: startDate)
                ) else { break }
                let periodComponents = calendar.dateComponents([.year, .month], from: monthDate)
                guard let year = periodComponents.year, let month = periodComponents.month else { break }

                let candidate: Date?
                switch monthlyRule {
                case .dayOfMonth(let day):
                    candidate = at(year: year, month: month, day: day)
                case .nthWeekday(let week, let weekday):
                    candidate = calendar.nthWeekday(week: week, weekday: weekday, year: year, month: month)
                        .flatMap { day in
                            at(year: year, month: month, day: day)
                        }
                }
                guard let next = candidate else { break }
                if endMode == .onDate, next > endDate { break }
                result.append(next)
            }
        case .yearly:
            while result.count < maxCount {
                guard let next = calendar.date(
                    byAdding: .year,
                    value: interval,
                    to: result[result.count - 1]
                ) else { break }
                if endMode == .onDate, next > endDate { break }
                result.append(next)
            }
        default:
            break
        }

        return Array(result.prefix(maxCount))
    }

    public static func summary(for rules: [EKRecurrenceRule]?, startDate: Date) -> String? {
        guard let rules, !rules.isEmpty else { return nil }
        guard let draft = EventRecurrenceDraft(rules: rules, startDate: startDate),
              draft.mode != .preserveExisting else {
            return "较复杂的自定义重复（宜历暂不支持修改）"
        }
        return draft.summaryText(startDate: startDate)
    }

    public func summaryText(startDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"

        switch endMode {
        case .never:
            return mode.title
        case .onDate:
            return "\(mode.title) · 至 \(formatter.string(from: endDate))"
        case .afterCount:
            return "\(mode.title) · \(occurrenceCount) 次"
        }
    }
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }

    func nthWeekday(week: Int, weekday: Int, year: Int, month: Int) -> Int? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let first = self.date(from: components) else { return nil }
        let firstWeekday = component(.weekday, from: first)
        let offset = (weekday - firstWeekday + 7) % 7
        return 1 + offset + (week - 1) * 7
    }
}
