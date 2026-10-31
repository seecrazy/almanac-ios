import Foundation

/// 某天的节假日效果
public enum DayEffect: Equatable {
    case restDay(name: String)   // 法定休：名称（如"春节"）
    case workday(name: String)   // 调休补班：所属节日名
}

/// 年度放假安排（JSON 反序列化模型）
public struct HolidayYear: Codable, Equatable {
    public let year: Int
    public let source: String?       // "official" | "sample" | "estimated"
    public let note: String?
    public let holidays: [HolidayGroup]
}

public struct HolidayGroup: Codable, Equatable {
    public let name: String
    public let daysOff: [String]     // yyyy-MM-dd
    public let workdays: [String]    // 调休补班日
}

/// 节假日查询引擎：数据与算法分离，年份 JSON 可独立更新（ADR-007）
public final class HolidayStore {

    private var restDays: [String: String] = [:]
    private var workdays: [String: String] = [:]

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = LunarCalendarShanghai.timezone
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public init(holidays: [HolidayGroup]) {
        for group in holidays {
            for day in group.daysOff { restDays[day] = group.name }
            for day in group.workdays { workdays[day] = group.name }
        }
    }

    public convenience init(json: Data) throws {
        let year = try JSONDecoder().decode(HolidayYear.self, from: json)
        self.init(holidays: year.holidays)
    }

    /// 某天的法定效果（nil = 非法定特殊日）
    public func effect(for date: Date) -> DayEffect? {
        let key = Self.keyFormatter.string(from: date)
        if let name = restDays[key] { return .restDay(name: name) }
        if let name = workdays[key] { return .workday(name: name) }
        return nil
    }

    /// 指定日期之后的下一个法定假日
    public func nextHoliday(after date: Date) -> (date: Date, name: String)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = LunarCalendarShanghai.timezone
        let keys = restDays.keys.sorted()
        for key in keys where key > Self.keyFormatter.string(from: date) {
            if let d = Self.keyFormatter.date(from: key) {
                return (d, restDays[key]!)
            }
        }
        return nil
    }
}

/// 与 LunarKit 相同的时区语义（独立声明以保持本包零依赖）
public enum LunarCalendarShanghai {
    public static let timezone = TimeZone(identifier: "Asia/Shanghai")!
}
