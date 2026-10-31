import Foundation

/// 重复频率（RFC 5545 子集；完整 RRULE 引擎见 roadmap v1.x）
public enum Frequency: String, Codable, CaseIterable {
    case daily, weekly, monthly, yearly
}

/// 星期（值对齐 Calendar.component(.weekday)：1=周日）
public enum RuleWeekday: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

/// 重复规则
public struct RecurrenceRule: Codable, Equatable {
    public var frequency: Frequency
    /// 间隔（每 N 天/周/月/年）
    public var interval: Int
    /// weekly 专用：每周生效日；nil = 起始日的星期
    public var byWeekday: [RuleWeekday]?
    /// 总次数上限（RFC COUNT：含被例外日剔除的槽位）
    public var count: Int?
    /// 截止日期
    public var until: Date?
    /// 例外日期（"这条删了，后面的还在"）
    public var excludedDates: [Date]

    public init(frequency: Frequency,
                interval: Int = 1,
                byWeekday: [RuleWeekday]? = nil,
                count: Int? = nil,
                until: Date? = nil,
                excludedDates: [Date] = []) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.byWeekday = byWeekday
        self.count = count
        self.until = until
        self.excludedDates = excludedDates
    }
}

/// 重复事件展开引擎
/// 设计要点：按周期步进（非逐天），支持 1985 年生日这类"远古起点"查询。
public enum RecurrenceEngine {

    public static func occurrences(of start: Date,
                                   rule: RecurrenceRule,
                                   in window: Range<Date>,
                                   calendar: Calendar = .current,
                                   maxIterations: Int = 100_000) -> [Date] {
        var result: [Date] = []
        var emitted = 0
        var iterations = 0
        let cap = rule.count ?? Int.max
        let excludedKeys = Set(rule.excludedDates.map { calendar.startOfDay(for: $0) })
        let weekdays = (rule.byWeekday?.isEmpty == false ? rule.byWeekday! : [RuleWeekday(rawValue: calendar.component(.weekday, from: start))!])
            .sorted { $0.rawValue < $1.rawValue }

        /// 候选日期统一携带 start 的时刻（周/月/年锚点都是 00:00，需还原时刻）
        let clock = calendar.dateComponents([.hour, .minute, .second], from: start)
        func at(_ day: Date) -> Date {
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = clock.hour; comps.minute = clock.minute; comps.second = clock.second
            return calendar.date(from: comps) ?? day
        }

        /// 记录一个候选：返回 false 表示应终止整个枚举
        func emit(_ candidate: Date) -> Bool {
            if let until = rule.until, candidate > until { return false }
            let isExcluded = excludedKeys.contains(calendar.startOfDay(for: candidate))
            emitted += 1                       // 例外日也消耗 COUNT 槽位（RFC 语义）
            if !isExcluded, emitted <= cap, window.contains(candidate) {
                result.append(candidate)
            }
            if emitted >= cap { return false }
            return true
        }

        switch rule.frequency {

        case .daily:
            var cursor = start
            while iterations < maxIterations {
                iterations += 1
                if cursor >= window.upperBound && emitted >= cap { break }
                let inWindowOrBefore = cursor < window.upperBound
                if !emit(cursor) { break }
                if !inWindowOrBefore { break }   // 已越过窗口且无 count 义务
                guard let next = calendar.date(byAdding: .day, value: rule.interval, to: cursor) else { break }
                cursor = next
            }

        case .weekly:
            guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start else { break }
            var weekIndex = 0
            weekLoop: while iterations < maxIterations {
                guard let weekStart = calendar.date(byAdding: .day, value: 7 * rule.interval * weekIndex, to: firstWeek) else { break }
                for weekday in weekdays {
                    iterations += 1
                    guard iterations < maxIterations else { break weekLoop }
                    guard let offsetDays = weekdayOffset(weekday, fromWeekStart: weekStart, calendar: calendar) else { continue }
                    guard let raw = calendar.date(byAdding: .day, value: offsetDays, to: weekStart) else { continue }
                    let candidate = at(raw)
                    guard candidate >= start else { continue }     // 起始周内早于 start 的槽位跳过
                    if candidate >= window.upperBound && emitted >= cap { break weekLoop }
                    if !emit(candidate) { break weekLoop }
                    if candidate >= window.upperBound && rule.count == nil { break weekLoop }
                }
                weekIndex += 1
                if rule.count != nil || rule.until != nil { continue }   // 有义务则继续走
                if let nextWeekStart = calendar.date(byAdding: .day, value: 7 * rule.interval, to: weekStart),
                   nextWeekStart >= window.upperBound { break }
            }

        case .monthly, .yearly:
            let startComps = calendar.dateComponents([.year, .month, .day], from: start)
            var periodIndex = 0
            while iterations < maxIterations {
                iterations += 1
                var comps = DateComponents()
                if rule.frequency == .monthly {
                    comps.year = startComps.year!
                    comps.month = startComps.month! + periodIndex * rule.interval
                } else {
                    comps.year = startComps.year! + periodIndex * rule.interval
                    comps.month = startComps.month!
                }
                comps.day = 1
                guard let firstOfMonth = calendar.date(from: comps) else { break }
                let actualMonth = calendar.component(.month, from: firstOfMonth)
                guard actualMonth == ((comps.month! - 1) % 12 + 1) else { periodIndex += 1; continue } // 短月无此日
                guard let raw = calendar.date(byAdding: .day, value: startComps.day! - 1, to: firstOfMonth) else { break }
                if calendar.component(.month, from: raw) != actualMonth { periodIndex += 1; continue }
                let candidate = at(raw)
                if candidate >= window.upperBound && emitted >= cap { break }
                if !emit(candidate) { break }
                if candidate >= window.upperBound && rule.count == nil { break }
                periodIndex += 1
            }
        }
        return result
    }

    /// 周内某星期相对周起始日的天数偏移
    private static func weekdayOffset(_ weekday: RuleWeekday, fromWeekStart: Date, calendar: Calendar) -> Int? {
        let startWeekday = calendar.component(.weekday, from: fromWeekStart)
        return mod(weekday.rawValue - startWeekday, 7)
    }

    @inline(__always)
    private static func mod(_ a: Int, _ n: Int) -> Int { (a % n + n) % n }
}
