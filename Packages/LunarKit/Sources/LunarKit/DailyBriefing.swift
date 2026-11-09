import Foundation

/// 每日简报的静态内容组装。所有字段由日期确定性推出，可提前多日预排通知。
public struct AlmanacBriefing: Hashable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public enum AlmanacBriefingComposer {
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    /// - Parameters:
    ///   - date: 目标日。
    ///   - rules: 黄历规则；nil 时简报省略宜忌。
    ///   - suitableLimit / avoidLimit: 宜忌条数上限。
    public static func compose(
        for date: Date,
        rules: AlmanacRuleSet?,
        suitableLimit: Int = 3,
        avoidLimit: Int = 3,
        showSolarTerm: Bool = true,
        showLunarFestival: Bool = true
    ) -> AlmanacBriefing {
        var lines: [String] = []

        let lunar = LunarCalendar.lunar(from: date)
        if LunarCalendar.isSupportedDate(date) {
            let leapPrefix = lunar.isLeapMonth ? "闰" : ""
            let ganZhi = GanZhi.yearGanZhi(forGregorianYear: lunar.year).ganZhi
            let lunarText = "\(leapPrefix)\(LunarCalendar.monthNames[lunar.month])\(LunarCalendar.dayNames[lunar.day])"
            lines.append("农历\(lunarText) · \(ganZhi)年")

            if showLunarFestival, let festival = LunarFestivalCalendar.festival(on: date) {
                lines.append("节日 · \(festival.name.rawValue)")
            }
            if showSolarTerm, let term = SolarTermCalendar.term(on: date) {
                lines.append("节气 · \(term.name.rawValue)")
            }

            if let rules {
                let day = AlmanacCalendar.day(for: date, rules: rules)
                if !day.suitable.isEmpty {
                    let items = day.suitable.prefix(suitableLimit).map(\.title).joined(separator: "、")
                    lines.append("宜：\(items)")
                }
                if !day.avoid.isEmpty {
                    let items = day.avoid.prefix(avoidLimit).map(\.title).joined(separator: "、")
                    lines.append("忌：\(items)")
                }
            }
        } else {
            lines.append("该日期超出农历支持范围（1900–2100）")
        }

        return AlmanacBriefing(
            title: titleFormatter.string(from: date),
            body: lines.joined(separator: "\n")
        )
    }
}
