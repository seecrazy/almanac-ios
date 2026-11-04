import Foundation

/// 二十四节气名称；`allCases` 保持公历年内的出现顺序。
public enum SolarTermName: String, CaseIterable, Codable, Hashable {
    case minorCold = "小寒"
    case majorCold = "大寒"
    case springBegins = "立春"
    case rainWater = "雨水"
    case insectsAwaken = "惊蛰"
    case springEquinox = "春分"
    case pureBrightness = "清明"
    case grainRain = "谷雨"
    case summerBegins = "立夏"
    case grainFull = "小满"
    case grainInEar = "芒种"
    case summerSolstice = "夏至"
    case minorHeat = "小暑"
    case majorHeat = "大暑"
    case autumnBegins = "立秋"
    case endOfHeat = "处暑"
    case whiteDew = "白露"
    case autumnEquinox = "秋分"
    case coldDew = "寒露"
    case frostDescent = "霜降"
    case winterBegins = "立冬"
    case minorSnow = "小雪"
    case majorSnow = "大雪"
    case winterSolstice = "冬至"

    /// 太阳视黄经目标角度。
    var eclipticLongitude: Double {
        switch self {
        case .springEquinox: return 0
        case .pureBrightness: return 15
        case .grainRain: return 30
        case .summerBegins: return 45
        case .grainFull: return 60
        case .grainInEar: return 75
        case .summerSolstice: return 90
        case .minorHeat: return 105
        case .majorHeat: return 120
        case .autumnBegins: return 135
        case .endOfHeat: return 150
        case .whiteDew: return 165
        case .autumnEquinox: return 180
        case .coldDew: return 195
        case .frostDescent: return 210
        case .winterBegins: return 225
        case .minorSnow: return 240
        case .majorSnow: return 255
        case .winterSolstice: return 270
        case .minorCold: return 285
        case .majorCold: return 300
        case .springBegins: return 315
        case .rainWater: return 330
        case .insectsAwaken: return 345
        }
    }
}

/// 一个节气发生时刻。`date` 是天文瞬时；日期归属由 `SolarTermCalendar` 用上海时区处理。
public struct SolarTerm: Identifiable, Hashable {
    public let name: SolarTermName
    public let date: Date

    public var id: String {
        "\(name.rawValue)-\(Int(date.timeIntervalSince1970))"
    }
}

/// 1900–2100 年二十四节气计算。
public enum SolarTermCalendar {
    public static let firstYear = LunarData.firstYear
    public static let lastYear = LunarData.firstYear + LunarData.info.count - 1
    public static let timezone = LunarCalendar.timeZone

    private static let tropicalYearDays = 365.242_189_67
    private static let degreesPerDay = 360 / tropicalYearDays
    private static let julianDayAtUnixEpoch = 2_440_587.5

    /// 返回指定公历年的 24 个节气，按发生时间升序排列。
    public static func terms(inGregorianYear year: Int) -> [SolarTerm]? {
        guard (firstYear...lastYear).contains(year) else { return nil }
        return SolarTermName.allCases.compactMap {
            term($0, inGregorianYear: year)
        }
    }

    /// 若上海日历上的“这一天”有节气，则返回该节气。
    public static func term(on date: Date) -> SolarTerm? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let year = calendar.component(.year, from: date)
        let targetDay = calendar.startOfDay(for: date)

        for candidateYear in [year - 1, year, year + 1] {
            guard let terms = terms(inGregorianYear: candidateYear) else { continue }
            if let match = terms.first(where: {
                calendar.startOfDay(for: $0.date) == targetDay
            }) {
                return match
            }
        }
        return nil
    }

    public static func displayName(for date: Date) -> String? {
        term(on: date)?.name.rawValue
    }

    private static func term(
        _ name: SolarTermName,
        inGregorianYear year: Int
    ) -> SolarTerm? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        components.hour = 0
        guard let januaryFirst = calendar.date(from: components) else { return nil }

        let initialUTDay = julianDay(from: januaryFirst)
        let initialDeltaT = deltaT(secondsForYear: year)
        let currentLongitude = apparentSolarLongitude(
            julianDayTT: initialUTDay + initialDeltaT / 86_400
        )
        let forwardDifference = positiveAngle(
            name.eclipticLongitude - currentLongitude
        )
        var estimateUTDay = initialUTDay + forwardDifference / degreesPerDay

        for _ in 0..<6 {
            let deltaT = deltaT(secondsForUTDay: estimateUTDay)
            let longitude = apparentSolarLongitude(
                julianDayTT: estimateUTDay + deltaT / 86_400
            )
            let signedDifference = signedAngle(
                name.eclipticLongitude - longitude
            )
            estimateUTDay += signedDifference / degreesPerDay
        }

        let finalDeltaT = deltaT(secondsForUTDay: estimateUTDay)
        let unixSeconds = (estimateUTDay - finalDeltaT / 86_400 - julianDayAtUnixEpoch) * 86_400
        return SolarTerm(name: name, date: Date(timeIntervalSince1970: unixSeconds))
    }

    /// Meeus 低精度太阳视黄经公式；日级展示足够，且便于跨平台复现。
    private static func apparentSolarLongitude(julianDayTT jd: Double) -> Double {
        let t = (jd - 2_451_545.0) / 36_525
        let meanLongitude = 280.466_46
            + 36_000.769_83 * t
            + 0.000_303_2 * t * t
        let meanAnomaly = 357.529_11
            + 35999.050_29 * t
            - 0.000_153_7 * t * t
        let center = (1.914_602 - 0.004_817 * t - 0.000_014 * t * t) * sin(meanAnomaly)
            + (0.019_993 - 0.000_101 * t) * sin(2 * meanAnomaly)
            + 0.000_289 * sin(3 * meanAnomaly)
        let trueLongitude = meanLongitude + center
        let moonNode = 125.04 - 1_934.136 * t
        return normalized(
            trueLongitude - 0.005_69 - 0.004_78 * sin(moonNode)
        )
    }

    /// 常用历史/预测 Delta T 近似；用于 UT 与 TT 换算，误差远小于节气日级验收口径。
    private static func deltaT(secondsForYear year: Int) -> Double {
        let anchors: [(year: Double, seconds: Double)] = [
            (1900, -2.7), (1920, 21.1), (1940, 24.3), (1950, 29.2),
            (1960, 33.2), (1970, 40.2), (1980, 50.5), (1990, 56.9),
            (2000, 63.8), (2010, 66.1), (2020, 69.4), (2040, 78.5),
            (2060, 113.3), (2080, 179.0), (2100, 252.0)
        ]

        let value = Double(year)
        guard value < anchors[0].year else {
            let last = anchors[anchors.count - 2]
            let edge = anchors[anchors.count - 1]
            let slope = (edge.seconds - last.seconds) / (edge.year - last.year)
            return edge.seconds + slope * (value - edge.year)
        }

        for index in 1..<anchors.count where value <= anchors[index].year {
            let left = anchors[index - 1]
            let right = anchors[index]
            let fraction = (value - left.year) / (right.year - left.year)
            return left.seconds + fraction * (right.seconds - left.seconds)
        }
        return anchors[anchors.count - 1].seconds
    }

    private static func deltaT(secondsForUTDay day: Double) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let year = calendar.component(
            .year,
            from: Date(timeIntervalSince1970: (day - julianDayAtUnixEpoch) * 86_400)
        )
        return deltaT(secondsForYear: year)
    }

    private static func julianDay(from date: Date) -> Double {
        julianDayAtUnixEpoch + date.timeIntervalSince1970 / 86_400
    }

    private static func normalized(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    private static func positiveAngle(_ angle: Double) -> Double {
        normalized(angle)
    }

    private static func signedAngle(_ angle: Double) -> Double {
        normalized(angle + 180) - 180
    }

    private static func sin(_ degrees: Double) -> Double {
        Foundation.sin(degrees * Double.pi / 180)
    }
}
