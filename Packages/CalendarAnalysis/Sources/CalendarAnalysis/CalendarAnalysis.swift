import Foundation

/// App 传给分析器的轻量日程模型；不依赖 EventKit 或 UI 框架。
public struct AnalysisEvent: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
    }
}

/// 一组彼此连通的重叠日程。
public struct AnalysisConflictGroup: Identifiable, Hashable {
    public let events: [AnalysisEvent]
    public let interval: DateInterval

    public var id: String {
        events.map(\.id).joined(separator: "|")
    }
}

/// 某个本地日历日内的可用空隙。
public struct AnalysisFreeSlot: Identifiable, Hashable {
    public let startDate: Date
    public let endDate: Date

    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    public var id: String {
        "\(Int(startDate.timeIntervalSince1970))-\(Int(endDate.timeIntervalSince1970))"
    }
}

public enum CalendarConflictAnalyzer {
    public static let maximumConflictGroups = 20
    public static let defaultMinimumFreeDuration: TimeInterval = 30 * 60
    public static let defaultMaximumFreeSlots = 6

    /// 计算连通冲突组；`within == nil` 时使用所有有效事件的公共时间范围。
    public static func conflictGroups(
        in events: [AnalysisEvent],
        within window: DateInterval? = nil
    ) -> [AnalysisConflictGroup] {
        let validEvents = events
            .filter { $0.endDate > $0.startDate }
            .compactMap { event -> (AnalysisEvent, DateInterval)? in
                let interval = DateInterval(start: event.startDate, end: event.endDate)
                guard let window else { return (event, interval) }
                guard interval.intersects(window) else { return nil }
                let intersection = interval.intersection(with: window) ?? interval
                return (event, intersection)
            }
            .sorted { left, right in
                if left.1.start != right.1.start {
                    return left.1.start < right.1.start
                }
                return left.1.end < right.1.end
            }

        var groups: [AnalysisConflictGroup] = []
        var currentEvents: [AnalysisEvent] = []
        var currentStart = Date.distantFuture
        var currentEnd = Date.distantPast

        func flush() {
            guard currentEvents.count >= 2 else {
                currentEvents = []
                currentStart = .distantFuture
                currentEnd = .distantPast
                return
            }
            let interval = DateInterval(
                start: currentStart,
                end: currentEnd
            )
            groups.append(
                AnalysisConflictGroup(events: currentEvents, interval: interval)
            )
            currentEvents = []
            currentStart = .distantFuture
            currentEnd = .distantPast
        }

        for (event, interval) in validEvents {
            if !currentEvents.isEmpty, interval.start < currentEnd {
                currentEvents.append(event)
                currentEnd = max(currentEnd, interval.end)
            } else {
                flush()
                currentEvents = [event]
                currentStart = interval.start
                currentEnd = interval.end
            }

            if groups.count >= maximumConflictGroups {
                return groups
            }
        }
        flush()

        return groups
    }

    /// 计算指定本地日历日内的空闲时段。全天事件会清空当天。
    public static func freeSlots(
        on date: Date,
        events: [AnalysisEvent],
        calendar: Calendar = .current,
        minimumDuration: TimeInterval = defaultMinimumFreeDuration,
        maximumCount: Int = defaultMaximumFreeSlots
    ) -> [AnalysisFreeSlot] {
        guard let dayInterval = calendar.dateInterval(of: .day, for: date),
              maximumCount > 0 else { return [] }

        if events.contains(where: { $0.isAllDay && $0.endDate > $0.startDate && $0.startDate < dayInterval.end && $0.endDate > dayInterval.start }) {
            return []
        }

        let busyIntervals = events
            .filter { !$0.isAllDay && $0.endDate > $0.startDate }
            .map { event -> DateInterval in
                DateInterval(
                    start: event.startDate,
                    end: event.endDate
                )
            }
            .filter { $0.intersects(dayInterval) }
            .compactMap { $0.intersection(with: dayInterval) }
            .sorted { left, right in
                if left.start != right.start {
                    return left.start < right.start
                }
                return left.end < right.end
            }

        var merged: [DateInterval] = []
        for busy in busyIntervals {
            if let last = merged.last, busy.start < last.end {
                let end = max(last.end, busy.end)
                merged[merged.count - 1] = DateInterval(start: last.start, end: end)
            } else {
                merged.append(busy)
            }
        }

        var cursor = dayInterval.start
        var slots: [AnalysisFreeSlot] = []
        let minimum = max(60, minimumDuration)

        for busy in merged {
            if busy.start.timeIntervalSince(cursor) >= minimum {
                slots.append(AnalysisFreeSlot(startDate: cursor, endDate: busy.start))
                if slots.count >= maximumCount { return slots }
            }
            cursor = max(cursor, busy.end)
        }

        if dayInterval.end.timeIntervalSince(cursor) >= minimum {
            slots.append(AnalysisFreeSlot(startDate: cursor, endDate: dayInterval.end))
        }
        return slots
    }
}
