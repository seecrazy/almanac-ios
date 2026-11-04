import Foundation
import LunarKit

var failures = 0
func check(_ cond: Bool, _ name: String) {
    print((cond ? "✅ " : "❌ ") + name)
    if !cond { failures += 1 }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = LunarCalendar.timeZone
func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
    return cal.date(from: comps)!
}

// 春节锚点：公历 → 农历正月初一
check(LunarCalendar.lunar(from: date(2026, 2, 17)) == LunarDate(year: 2026, month: 1, day: 1), "2026-02-17 → 丙午年正月初一（春节）")
check(LunarCalendar.lunar(from: date(2025, 1, 29)) == LunarDate(year: 2025, month: 1, day: 1), "2025-01-29 → 乙巳年正月初一（春节）")
check(LunarCalendar.lunar(from: date(2024, 2, 10)) == LunarDate(year: 2024, month: 1, day: 1), "2024-02-10 → 甲辰年正月初一（春节）")

// 中秋锚点
check(LunarCalendar.lunar(from: date(2024, 9, 17)) == LunarDate(year: 2024, month: 8, day: 15), "2024-09-17 → 八月十五（中秋）")

// 闰月
check(LunarCalendar.leapMonth(of: 2023) == 2, "2023 闰二月")
check(LunarCalendar.leapMonth(of: 2025) == 6, "2025 闰六月")
check(LunarCalendar.leapMonth(of: 2026) == 0, "2026 无闰月")

// 往返一致性
let samples = [date(2026, 2, 17), date(2024, 9, 17), date(2026, 10, 31)]
for d in samples {
    let lunar = LunarCalendar.lunar(from: d)
    let back = LunarCalendar.solar(from: lunar)
    check(cal.isDate(back!, inSameDayAs: d), "往返一致 \(d)")
}

// 文本
check(LunarCalendar.displayText(for: LunarDate(year: 2026, month: 1, day: 1)) == "正月", "初一显示月名")
check(LunarCalendar.displayText(for: LunarDate(year: 2024, month: 8, day: 15)) == "十五", "十五显示日名")
check(LunarCalendar.displayText(for: LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true)) == "闰六月", "闰月初一显示闰月名")
check(LunarCalendar.displayText(for: LunarDate(year: 2023, month: 2, day: 3, isLeapMonth: true)) == "初三", "闰月非初一显示日名")

// 干支
check(GanZhi.dayGanZhi(for: date(1949, 10, 1)) == "甲子", "1949-10-01 甲子日")
check(GanZhi.yearGanZhi(forGregorianYear: 2026).ganZhi == "丙午", "2026 丙午年")
check(GanZhi.yearGanZhi(forGregorianYear: 2026).zodiac == "马", "2026 马年")

// 二十四节气
if let terms = SolarTermCalendar.terms(inGregorianYear: 2026) {
    check(terms.count == 24, "2026 年有 24 个节气")
    check(SolarTermCalendar.displayName(for: date(2026, 2, 4)) == "立春", "2026-02-04 立春")
    check(SolarTermCalendar.displayName(for: date(2026, 12, 22)) == "冬至", "2026-12-22 冬至")
}
check(LunarFestivalCalendar.displayName(for: date(2026, 2, 17)) == "春节", "2026-02-17 春节")
check(LunarFestivalCalendar.displayName(for: date(2024, 9, 17)) == "中秋节", "2024-09-17 中秋节")
check(LunarFestivalCalendar.displayName(for: date(2025, 1, 28)) == "除夕", "2025-01-28 除夕")

// 今天
let today = LunarCalendar.lunar(from: Date())
print("----")
print("今天农历：\(today.isLeapMonth ? "闰" : "")\(LunarCalendar.monthNames[today.month])\(LunarCalendar.dayNames[today.day])")
print("今天干支：\(GanZhi.dayGanZhi(for: Date())) / \(GanZhi.yearGanZhi(forGregorianYear: cal.component(.year, from: Date())).zodiac)年")

exit(failures == 0 ? 0 : 1)
