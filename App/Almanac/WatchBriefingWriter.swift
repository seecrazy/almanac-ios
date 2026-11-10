import Foundation
import HolidayData
import LunarKit
import MilestoneKit

/// watchOS 快照写入（ADR-012）：App 激活 / 显著时间变化时刷新。
/// 手表侧只读该快照，不直接触碰 EventKit / 通知。
enum WatchBriefingWriter {
    @MainActor
    static func sync(
        referenceDate: Date = Date(),
        eventService: EventStoreService,
        milestoneStore: MilestoneStore,
        alarmStore: WorkdayAlarmStore
    ) {
        let day = referenceDate
        var lunarText = ""
        var festivalText: String?
        var solarTermText: String?
        var suitableText: String?
        var avoidText: String?

        if LunarCalendar.isSupportedDate(day) {
            let lunar = LunarCalendar.lunar(from: day)
            let leapPrefix = lunar.isLeapMonth ? "闰" : ""
            let ganZhi = GanZhi.yearGanZhi(forGregorianYear: lunar.year).ganZhi
            lunarText = "农历\(leapPrefix)\(LunarCalendar.monthNames[lunar.month])\(LunarCalendar.dayNames[lunar.day]) · \(ganZhi)年"
            if let festival = LunarFestivalCalendar.festival(on: day) {
                festivalText = "节日 · \(festival.name.rawValue)"
            }
            if let term = SolarTermCalendar.term(on: day) {
                solarTermText = "节气 · \(term.name.rawValue)"
            }
            if let rules = AlmanacRuleSet.bundledShared {
                let almanacDay = AlmanacCalendar.day(for: day, rules: rules)
                if !almanacDay.suitable.isEmpty {
                    suitableText = "宜：" + almanacDay.suitable.prefix(3).map(\.title).joined(separator: "、")
                }
                if !almanacDay.avoid.isEmpty {
                    avoidText = "忌：" + almanacDay.avoid.prefix(3).map(\.title).joined(separator: "、")
                }
            }
        } else {
            lunarText = "超出农历支持范围"
        }

        let nextMilestone = milestoneStore
            .sortedMilestones(at: referenceDate)
            .first { !$0.isPast(reference: referenceDate) }
        let nextAlarm = alarmStore.occurrences.first

        let snapshot = WatchBriefingSnapshot(
            generatedAt: referenceDate,
            day: day,
            lunarText: lunarText,
            festivalText: festivalText,
            solarTermText: solarTermText,
            suitableText: suitableText,
            avoidText: avoidText,
            nextMilestoneTitle: nextMilestone?.title,
            nextMilestoneDate: nextMilestone?.targetDate,
            nextAlarmName: nextAlarm?.alarm.name.isEmpty == true ? "闹钟" : nextAlarm?.alarm.name,
            nextAlarmFireDate: nextAlarm?.fireDate,
            todayEventCount: eventService.events(on: day).count
        )

        write(snapshot)
    }

    private static func write(_ snapshot: WatchBriefingSnapshot) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WatchBriefingStorage.appGroupIdentifier
        ) else {
            return
        }
        let directory = container.appendingPathComponent("Widgets", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(WatchBriefingStorage.fileName)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

private extension Milestone {
    func isPast(reference: Date) -> Bool {
        effectiveSortDate < reference
    }
}
