import Foundation

public enum AlmanacSource: String, Codable, Hashable {
    case rule
    case bundledTable
}

public struct AlmanacClash: Hashable {
    public let dayBranch: String
    public let conflictBranch: String
    public let direction: String?

    public init(dayBranch: String, conflictBranch: String, direction: String? = nil) {
        self.dayBranch = dayBranch
        self.conflictBranch = conflictBranch
        self.direction = direction
    }
}

public struct AlmanacActivity: Hashable, Identifiable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct AlmanacDay: Hashable {
    public let date: Date
    public let lunar: LunarDate?
    public let yearGanZhi: String
    public let monthGanZhi: String
    public let dayGanZhi: String
    public let zodiac: String
    public let duty: String
    public let clash: AlmanacClash?
    public let suitable: [AlmanacActivity]
    public let avoid: [AlmanacActivity]
    public let source: AlmanacSource
}

public struct AlmanacClashRule: Codable, Hashable {
    public let dayBranch: String
    public let conflictBranch: String
    public let direction: String
}

public struct AlmanacActivityRule: Codable, Hashable {
    public let id: String
    public let title: String
    public let suitableDuties: [String]
    public let avoidDuties: [String]
}

public struct AlmanacRuleSet: Codable, Hashable {
    public let version: Int
    public let duties: [String]
    public let clash: [AlmanacClashRule]
    public let activities: [AlmanacActivityRule]

    public static func bundled() -> AlmanacRuleSet? {
        bundled(bundle: .module)
    }

    public static func bundled(bundle: Bundle) -> AlmanacRuleSet? {
        guard let url = bundle.url(forResource: "almanac-rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decode(from: data)
    }

    public static func decode(from data: Data) throws -> AlmanacRuleSet {
        try JSONDecoder().decode(AlmanacRuleSet.self, from: data)
    }
}

public enum AlmanacCalendar {
    public static func day(
        for date: Date,
        rules: AlmanacRuleSet?
    ) -> AlmanacDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = LunarCalendar.timeZone
        let dayStart = calendar.startOfDay(for: date)
        let lunar = LunarCalendar.lunar(from: dayStart)
        let lunarSupported = LunarCalendar.isSupportedDate(dayStart)

        let dayIndex = GanZhi.dayGanZhiIndex(for: dayStart)
        let almanacYear = lunarSupported ? lunar.year : calendar.component(.year, from: dayStart)
        let yearIndex = ((almanacYear - 4) % 60 + 60) % 60
        let monthStemIndex = ((yearIndex % 10) * 2 + 2 + lunar.month - 1 + 100) % 10
        let monthBranchIndex = (lunar.month + 1) % 12
        let dayStemIndex = dayIndex % 10
        let dayBranchIndex = dayIndex % 12

        let duty: String
        if let rules, !rules.duties.isEmpty {
            let index = (dayBranchIndex - monthBranchIndex + 12) % 12 % rules.duties.count
            duty = rules.duties[index]
        } else {
            duty = GanZhi.branches[dayBranchIndex]
        }
        let clash = rules?.clash.first { $0.dayBranch == GanZhi.branches[dayBranchIndex] }
        let activities = filterActivities(rules?.activities ?? [], duty: duty)

        return AlmanacDay(
            date: dayStart,
            lunar: lunarSupported ? lunar : nil,
            yearGanZhi: GanZhi.stems[yearIndex % 10] + GanZhi.branches[yearIndex % 12],
            monthGanZhi: GanZhi.stems[monthStemIndex] + GanZhi.branches[monthBranchIndex],
            dayGanZhi: GanZhi.stems[dayStemIndex] + GanZhi.branches[dayBranchIndex],
            zodiac: GanZhi.zodiac[yearIndex % 12],
            duty: duty,
            clash: clash.map {
                AlmanacClash(
                    dayBranch: $0.dayBranch,
                    conflictBranch: $0.conflictBranch,
                    direction: $0.direction
                )
            },
            suitable: activities.suitable,
            avoid: activities.avoid,
            source: rules == nil ? .bundledTable : .rule
        )
    }

    static func filterActivities(
        _ rules: [AlmanacActivityRule],
        duty: String
    ) -> (suitable: [AlmanacActivity], avoid: [AlmanacActivity]) {
        var suitable: [AlmanacActivity] = []
        var avoid: [AlmanacActivity] = []

        for rule in rules {
            let isSuitable = rule.suitableDuties.contains(duty)
            let isAvoid = rule.avoidDuties.contains(duty)
            if isAvoid {
                avoid.append(AlmanacActivity(id: rule.id, title: rule.title))
            } else if isSuitable {
                suitable.append(AlmanacActivity(id: rule.id, title: rule.title))
            }
        }

        return (suitable, avoid)
    }
}
