import Foundation

public enum EventSearchRange: Codable, Hashable {
    case next7Days
    case next30Days
    case pastAndNext90Days
    case past180ToFuture365Days
    case custom(start: Date, end: Date)

    public var title: String {
        switch self {
        case .next7Days: return "未来 7 天"
        case .next30Days: return "未来 30 天"
        case .pastAndNext90Days: return "近 90 天"
        case .past180ToFuture365Days: return "常用"
        case .custom: return "自定义"
        }
    }

    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}

public struct ResolvedEventSearchInterval: Hashable {
    public let interval: DateInterval
    public let wasCapped: Bool

    public init(interval: DateInterval, wasCapped: Bool = false) {
        self.interval = interval
        self.wasCapped = wasCapped
    }
}

public struct EventSearchQuery: Hashable {
    public var keyword: String
    public var range: EventSearchRange
    public var calendarIDs: Set<String>?
    public var includeAllDay: Bool

    public init(
        keyword: String,
        range: EventSearchRange = .past180ToFuture365Days,
        calendarIDs: Set<String>? = nil,
        includeAllDay: Bool = true
    ) {
        self.keyword = keyword
        self.range = range
        self.calendarIDs = calendarIDs
        self.includeAllDay = includeAllDay
    }

    public var trimmedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canSearch: Bool {
        !trimmedKeyword.isEmpty
    }

    public func resolvedInterval(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> ResolvedEventSearchInterval {
        let start: Date
        let end: Date

        switch range {
        case .next7Days:
            start = referenceDate
            end = calendar.date(byAdding: .day, value: 7, to: referenceDate) ?? referenceDate
        case .next30Days:
            start = referenceDate
            end = calendar.date(byAdding: .day, value: 30, to: referenceDate) ?? referenceDate
        case .pastAndNext90Days:
            start = calendar.date(byAdding: .day, value: -90, to: referenceDate) ?? referenceDate
            end = calendar.date(byAdding: .day, value: 90, to: referenceDate) ?? referenceDate
        case .past180ToFuture365Days:
            start = calendar.date(byAdding: .day, value: -180, to: referenceDate) ?? referenceDate
            end = calendar.date(byAdding: .day, value: 365, to: referenceDate) ?? referenceDate
        case .custom(let customStart, let customEnd):
            start = min(customStart, customEnd)
            end = max(customStart, customEnd)
        }

        let maximumEnd = start.addingTimeInterval(730 * 24 * 60 * 60)
        let cappedEnd = min(end, maximumEnd)
        return ResolvedEventSearchInterval(
            interval: DateInterval(start: start, end: cappedEnd),
            wasCapped: end > cappedEnd
        )
    }
}
