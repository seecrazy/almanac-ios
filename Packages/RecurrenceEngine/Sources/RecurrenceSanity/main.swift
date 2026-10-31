import Foundation
import RecurrenceEngine

var failures = 0
func check(_ cond: Bool, _ name: String) {
    print((cond ? "✅ " : "❌ ") + name)
    if !cond { failures += 1 }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
    var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d; comps.hour = h
    return cal.date(from: comps)!
}
let nov = date(2026, 11, 1, 0) ..< date(2026, 12, 1, 0)
let days = { (ds: [Date]) in ds.map { cal.component(.day, from: $0) } }

// 1. 每周一/三（2026-11-01 是周日，首个生效日 11-02）
let weekly = RecurrenceRule(frequency: .weekly, byWeekday: [.monday, .wednesday])
let weeklyDates = RecurrenceEngine.occurrences(of: date(2026, 11, 2), rule: weekly, in: nov, calendar: cal)
check(days(weeklyDates) == [2, 4, 9, 11, 16, 18, 23, 25, 30], "每周一/三 → \(days(weeklyDates))")

// 2. 每隔 3 天
let daily3 = RecurrenceRule(frequency: .daily, interval: 3)
let daily3Dates = RecurrenceEngine.occurrences(of: date(2026, 11, 1), rule: daily3, in: nov, calendar: cal)
check(days(daily3Dates) == [1, 4, 7, 10, 13, 16, 19, 22, 25, 28], "每 3 天 → \(days(daily3Dates))")

// 3. count 上限
let counted = RecurrenceRule(frequency: .weekly, byWeekday: [.friday], count: 3)
let countedDates = RecurrenceEngine.occurrences(of: date(2026, 11, 6), rule: counted, in: nov, calendar: cal)
check(days(countedDates) == [6, 13, 20], "count=3 → \(days(countedDates))")

// 4. 例外日期
let withEx = RecurrenceRule(frequency: .daily, excludedDates: [date(2026, 11, 2)])
let exDates = RecurrenceEngine.occurrences(of: date(2026, 11, 1), rule: withEx, in: nov, calendar: cal)
check(days(exDates).count == 29 && !days(exDates).contains(2), "例外日剔除 → 29 天且不含 2 号")

// 5. 每年（生日场景）
let yearly = RecurrenceRule(frequency: .yearly)
let years = RecurrenceEngine.occurrences(of: date(1985, 6, 15), rule: yearly,
                                         in: date(2024, 1, 1, 0) ..< date(2028, 1, 1, 0), calendar: cal)
check(years.count == 4, "每年生日 2024-2027 → 4 次")

// 6. 每 2 周（大小周场景）
let biweekly = RecurrenceRule(frequency: .weekly, interval: 2, byWeekday: [.saturday])
let biweeklyDates = RecurrenceEngine.occurrences(of: date(2026, 11, 7), rule: biweekly, in: nov, calendar: cal)
check(days(biweeklyDates) == [7, 21], "双周周六 → \(days(biweeklyDates))")

exit(failures == 0 ? 0 : 1)
