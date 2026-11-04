import Foundation

public enum NaturalRecurrenceMode: String, Codable, CaseIterable, Sendable {
    case none
    case daily
    case weekly
    case biweekly
    case monthly
    case yearly
}

public struct NaturalInputRules: Codable, Equatable, Sendable {
    public struct RecurrenceRule: Codable, Equatable, Sendable {
        public let patterns: [String]
        public let mode: NaturalRecurrenceMode
    }

    public let version: Int
    public let locale: String
    public let allDayMarkers: [String]
    public let relativeDates: [String: Int]
    public let nextWeekPrefixes: [String]
    public let weekdayPrefixes: [String]
    public let weekdayAliases: [String: Int]
    public let recurrenceRules: [RecurrenceRule]
    public let locationMarker: String
    public let notesMarker: String

    public static func bundled() -> NaturalInputRules {
        let url = Bundle.module.url(
            forResource: "natural-input-rules",
            withExtension: "json"
        )
        guard let url,
              let data = try? Data(contentsOf: url),
              let rules = try? JSONDecoder().decode(NaturalInputRules.self, from: data)
        else {
            return .fallback
        }
        return rules
    }

    public static let fallback = NaturalInputRules(
        version: 1,
        locale: "zh-Hans-CN",
        allDayMarkers: ["全天"],
        relativeDates: ["今天": 0, "今日": 0, "明天": 1, "后天": 2, "大后天": 3],
        nextWeekPrefixes: ["下星期", "下周", "下礼拜"],
        weekdayPrefixes: ["星期", "礼拜", "周"],
        weekdayAliases: ["一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7, "日": 1, "天": 1],
        recurrenceRules: [
            .init(patterns: ["每天", "每日"], mode: .daily),
            .init(patterns: ["每周一次", "每个星期", "每星期", "每周"], mode: .weekly),
            .init(patterns: ["每两周", "隔周"], mode: .biweekly),
            .init(patterns: ["每月"], mode: .monthly),
            .init(patterns: ["每年"], mode: .yearly)
        ],
        locationMarker: "@",
        notesMarker: "#"
    )
}
