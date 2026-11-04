import Foundation

/// 农历日期
public struct LunarDate: Equatable, Hashable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let isLeapMonth: Bool

    public init(year: Int, month: Int, day: Int, isLeapMonth: Bool = false) {
        self.year = year
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }
}

/// 公历 ↔ 农历换算（ Asia/Shanghai 语义，覆盖 1900–2100 ）
public enum LunarCalendar {

    /// 农历计算以北京时间为准（日期归属不受设备时区/夏令时影响）
    public static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    /// 基准：1900-01-31 = 农历 1900 年正月初一
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }()

    // MARK: - 公历 → 农历

    public static func lunar(from date: Date) -> LunarDate {
        var offset = dayOffset(from: date)

        var year = LunarData.firstYear
        while year < LunarData.firstYear + LunarData.info.count {
            let days = daysInLunarYear(year)
            if offset < days { break }
            offset -= days
            year += 1
        }

        let leap = leapMonth(of: year)
        var month = 1
        let isLeap = false
        while month <= 12 {
            // 先处理闰月（闰 X 月在 X 月之前）
            if leap > 0, month == leap, !isLeap {
                let days = daysInLunarMonth(year, month, isLeapMonth: true)
                if offset < days { return LunarDate(year: year, month: month, day: offset + 1, isLeapMonth: true) }
                offset -= days
            }
            let days = daysInLunarMonth(year, month, isLeapMonth: false)
            if offset < days { break }
            offset -= days
            month += 1
        }
        return LunarDate(year: year, month: month, day: offset + 1, isLeapMonth: isLeap)
    }

    // MARK: - 农历 → 公历

    public static func solar(from lunar: LunarDate) -> Date? {
        guard lunar.year >= LunarData.firstYear,
              lunar.year < LunarData.firstYear + LunarData.info.count,
              (1...12).contains(lunar.month),
              let leap = leapOrZero(lunar) else { return nil }
        var offset = 0
        var y = LunarData.firstYear
        while y < lunar.year {
            offset += daysInLunarYear(y)
            y += 1
        }
        var m = 1
        while m < lunar.month {
            if leap > 0, m == leap {
                offset += daysInLunarMonth(lunar.year, m, isLeapMonth: true)
            }
            offset += daysInLunarMonth(lunar.year, m, isLeapMonth: false)
            m += 1
        }
        // 闰 X 月紧贴在正常 X 月之前：进入正常/闰 X 月都要跨过闰月。
        if leap == lunar.month {
            offset += daysInLunarMonth(lunar.year, lunar.month, isLeapMonth: true)
        }
        if lunar.isLeapMonth {
            guard leap == lunar.month else { return nil }
            offset += daysInLunarMonth(lunar.year, lunar.month, isLeapMonth: false)
        }
        offset += lunar.day - 1
        return calendar.date(byAdding: .day, value: offset, to: baseDate)
    }

    // MARK: - 年月日属性

    /// 某农历年的闰月月份（0 = 无闰月）
    public static func leapMonth(of lunarYear: Int) -> Int {
        guard let bits = bits(for: lunarYear) else { return 0 }
        return Int(bits & 0xF)
    }

    /// 农历某月天数（29 或 30）
    public static func daysInLunarMonth(_ lunarYear: Int, _ month: Int, isLeapMonth: Bool) -> Int {
        guard let bits = bits(for: lunarYear), (1...12).contains(month) else { return 29 }
        let leap = Int(bits & 0xF)
        if isLeapMonth {
            guard month == leap else { return 29 }
            return (bits >> 16) & 1 == 1 ? 30 : 29
        }
        return (bits >> (16 - month)) & 1 == 1 ? 30 : 29
    }

    /// 农历年总天数
    public static func daysInLunarYear(_ lunarYear: Int) -> Int {
        var total = 0
        let leap = leapMonth(of: lunarYear)
        for m in 1...12 { total += daysInLunarMonth(lunarYear, m, isLeapMonth: false) }
        if leap > 0 { total += daysInLunarMonth(lunarYear, leap, isLeapMonth: true) }
        return total
    }

    /// 日期是否严格落在农历数据支持范围内（1900-01-31 起至 2100 年腊月最后一天）
    public static func isSupportedDate(_ date: Date) -> Bool {
        let offset = dayOffset(from: date)
        guard offset >= 0 else { return false }

        var totalDays = 0
        for year in LunarData.firstYear..<(LunarData.firstYear + LunarData.info.count) {
            totalDays += daysInLunarYear(year)
        }
        return offset < totalDays
    }

    // MARK: - 文本（月视图用）

    public static let monthNames = ["", "正月", "二月", "三月", "四月", "五月", "六月",
                                     "七月", "八月", "九月", "十月", "冬月", "腊月"]
    public static let dayNames = ["", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                                   "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                                   "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]

    /// 月视图小字：初一显示月名（含闰/腊月），其余显示日名
    public static func displayText(for lunar: LunarDate) -> String {
        if lunar.day == 1 {
            let leapPrefix = lunar.isLeapMonth ? "闰" : ""
            return leapPrefix + monthNames[lunar.month]
        }
        return dayNames[lunar.day]
    }

    // MARK: - Private

    private static let baseDate: Date = {
        var c = DateComponents()
        c.year = 1900; c.month = 1; c.day = 31
        return calendar.date(from: c)!
    }()

    private static func dayOffset(from date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: baseDate), to: start).day!
    }

    private static func bits(for lunarYear: Int) -> UInt32? {
        let i = lunarYear - LunarData.firstYear
        guard i >= 0, i < LunarData.info.count else { return nil }
        return LunarData.info[i]
    }

    private static func leapOrZero(_ lunar: LunarDate) -> Int? {
        guard let bits = bits(for: lunar.year) else { return nil }
        let leap = Int(bits & 0xF)
        if lunar.isLeapMonth, leap != lunar.month { return nil }
        return leap
    }
}
