import Foundation

/// 常见农历节日；`allCases` 只用于目录，不表示公历年内出现顺序。
public enum LunarFestivalName: String, CaseIterable, Codable, Hashable {
    case springFestival = "春节"
    case lanternFestival = "元宵节"
    case dragonHeadRaising = "龙抬头"
    case shangsiFestival = "上巳节"
    case qixiFestival = "七夕"
    case zhongyuanFestival = "中元节"
    case midAutumnFestival = "中秋节"
    case chongyangFestival = "重阳节"
    case labaFestival = "腊八节"
    case newYearsEve = "除夕"
}

/// 一个农历节日及其公历发生时刻。
public struct LunarFestival: Identifiable, Hashable {
    public let name: LunarFestivalName
    public let date: Date

    public var id: String {
        "\(name.rawValue)-\(Int(date.timeIntervalSince1970))"
    }
}

/// 1900–2100 农历年常见节日计算。
public enum LunarFestivalCalendar {
    public static let firstLunarYear = LunarData.firstYear
    public static let lastLunarYear = LunarData.firstYear + LunarData.info.count - 1
    public static let timezone = LunarCalendar.timeZone

    /// 返回指定农历年的节日，按公历日期升序。
    /// 农历 2100 年的除夕需要 2101 年春节数据，因此会省略除夕。
    public static func festivals(inLunarYear year: Int) -> [LunarFestival]? {
        guard (firstLunarYear...lastLunarYear).contains(year) else { return nil }

        let fixedFestivals: [(LunarFestivalName, LunarDate)] = [
            (.springFestival, LunarDate(year: year, month: 1, day: 1)),
            (.lanternFestival, LunarDate(year: year, month: 1, day: 15)),
            (.dragonHeadRaising, LunarDate(year: year, month: 2, day: 2)),
            (.shangsiFestival, LunarDate(year: year, month: 3, day: 3)),
            (.qixiFestival, LunarDate(year: year, month: 7, day: 7)),
            (.zhongyuanFestival, LunarDate(year: year, month: 7, day: 15)),
            (.midAutumnFestival, LunarDate(year: year, month: 8, day: 15)),
            (.chongyangFestival, LunarDate(year: year, month: 9, day: 9)),
            (.labaFestival, LunarDate(year: year, month: 12, day: 8))
        ]

        var festivals = fixedFestivals.compactMap { name, lunarDate -> LunarFestival? in
            LunarCalendar.solar(from: lunarDate).map {
                LunarFestival(name: name, date: $0)
            }
        }

        if year < lastLunarYear,
           let nextSpringFestival = LunarCalendar.solar(
               from: LunarDate(year: year + 1, month: 1, day: 1)
           ),
           let newYearsEve = Calendar(identifier: .gregorian).date(
               byAdding: .day,
               value: -1,
               to: nextSpringFestival
           ) {
            festivals.append(
                LunarFestival(name: .newYearsEve, date: newYearsEve)
            )
        }

        return festivals.sorted { $0.date < $1.date }
    }

    /// 若上海日历上的“这一天”是农历节日，则返回该节日。
    public static func festival(on date: Date) -> LunarFestival? {
        guard LunarCalendar.isSupportedDate(date) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let targetDay = calendar.startOfDay(for: date)
        let lunarYear = LunarCalendar.lunar(from: date).year

        guard let festivals = festivals(inLunarYear: lunarYear) else { return nil }
        return festivals.first {
            calendar.startOfDay(for: $0.date) == targetDay
        }
    }

    public static func displayName(for date: Date) -> String? {
        festival(on: date)?.name.rawValue
    }
}
