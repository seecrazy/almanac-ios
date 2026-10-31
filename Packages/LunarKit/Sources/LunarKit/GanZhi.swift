import Foundation

/// 干支、生肖（锚点：1949-10-01 为甲子日）
public enum GanZhi {

    public static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    public static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    public static let zodiac = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    /// 干支纪年（以农历年为界的严格版本见黄历模块；此处为公历年近似）
    public static func yearGanZhi(forGregorianYear year: Int) -> (ganZhi: String, zodiac: String) {
        let s = stems[mod(year - 4, 10)]
        let b = branches[mod(year - 4, 12)]
        return (s + b, zodiac[mod(year - 4, 12)])
    }

    /// 干支纪日
    public static func dayGanZhi(for date: Date) -> String {
        let idx = dayGanZhiIndex(for: date)
        return stems[idx % 10] + branches[idx % 12]
    }

    /// 干支纪日索引（0 = 甲子）
    public static func dayGanZhiIndex(for date: Date) -> Int {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = LunarCalendar.timeZone
        var comps = DateComponents()
        comps.year = 1949; comps.month = 10; comps.day = 1   // 甲子日锚点
        let anchor = c.startOfDay(for: c.date(from: comps)!)
        let offset = c.dateComponents([.day], from: anchor, to: c.startOfDay(for: date)).day!
        return mod(offset, 60)
    }

    @inline(__always)
    static func mod(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r < 0 ? r + n : r
    }
}
