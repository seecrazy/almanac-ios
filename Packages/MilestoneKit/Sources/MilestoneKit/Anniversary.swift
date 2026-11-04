import Foundation
import LunarKit

public enum AnniversaryKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case birthday
    case memorial
    case wedding
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .birthday: return "生日"
        case .memorial: return "纪念日"
        case .wedding: return "结婚纪念日"
        case .custom: return "自定义"
        }
    }
}

public enum AnniversaryCalendar: String, Codable, CaseIterable, Identifiable, Hashable {
    case solar
    case lunar

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .solar: return "阳历"
        case .lunar: return "农历"
        }
    }
}

public enum LeapMonthFallback: String, Codable, CaseIterable, Identifiable, Hashable {
    case previousCommonMonth
    case nextCommonMonth
    case skipYear

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .previousCommonMonth: return "回退普通月"
        case .nextCommonMonth: return "顺延普通月"
        case .skipYear: return "跳过无闰年份"
        }
    }
}

public struct LunarDateSpec: Codable, Hashable {
    public var originalYear: Int?
    public var month: Int
    public var day: Int
    public var isLeapMonth: Bool

    public init(
        originalYear: Int? = nil,
        month: Int,
        day: Int,
        isLeapMonth: Bool = false
    ) {
        self.originalYear = originalYear
        self.month = month
        self.day = day
        self.isLeapMonth = isLeapMonth
    }
}

public struct Anniversary: Identifiable, Codable, Hashable {
    public let id: UUID
    public var title: String
    public var personName: String?
    public var kind: AnniversaryKind
    public var calendar: AnniversaryCalendar
    public var solarDate: DateComponents?
    public var lunarDate: LunarDateSpec?
    public var leapMonthFallback: LeapMonthFallback
    public var showAge: Bool
    public var showAnniversaryYears: Bool
    public var reminders: [MilestoneReminder]
    public var notes: String
    public var createdAt: Date
    public var resolvedDate: Date?
    public var resolvedWithFallback: Bool?

    public init(
        id: UUID = UUID(),
        title: String,
        personName: String? = nil,
        kind: AnniversaryKind,
        calendar: AnniversaryCalendar,
        solarDate: DateComponents? = nil,
        lunarDate: LunarDateSpec? = nil,
        leapMonthFallback: LeapMonthFallback = .previousCommonMonth,
        showAge: Bool = true,
        showAnniversaryYears: Bool = true,
        reminders: [MilestoneReminder] = [],
        notes: String = "",
        createdAt: Date = Date(),
        resolvedDate: Date? = nil,
        resolvedWithFallback: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.personName = personName
        self.kind = kind
        self.calendar = calendar
        self.solarDate = solarDate
        self.lunarDate = lunarDate
        self.leapMonthFallback = leapMonthFallback
        self.showAge = showAge
        self.showAnniversaryYears = showAnniversaryYears
        self.reminders = reminders
        self.notes = notes
        self.createdAt = createdAt
        self.resolvedDate = resolvedDate
        self.resolvedWithFallback = resolvedWithFallback
    }

    public var isValid: Bool {
        switch calendar {
        case .solar:
            guard let date = solarDate,
                  let year = date.year,
                  let month = date.month,
                  let day = date.day else { return false }
            return (1...12).contains(month) && (1...31).contains(day) && year > 0
        case .lunar:
            guard let date = lunarDate else { return false }
            return (1...12).contains(date.month) && (1...30).contains(date.day)
        }
    }

    public var notificationTitle: String {
        let person = personName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPerson = person?.isEmpty == false
        switch kind {
        case .birthday:
            return hasPerson ? "\(person!)的生日" : title
        case .memorial:
            return hasPerson ? "\(person!)的纪念日" : title
        case .wedding:
            return title.isEmpty ? "结婚纪念日" : title
        case .custom:
            return title
        }
    }
}

public struct AnniversaryOccurrence: Identifiable, Hashable {
    public let id: UUID
    public let anniversary: Anniversary
    public let date: Date
    public let isFallback: Bool
    public let fallbackNote: String?
    public let count: Int?
    public let countText: String?

    public init(
        id: UUID,
        anniversary: Anniversary,
        date: Date,
        isFallback: Bool,
        fallbackNote: String?,
        count: Int?,
        countText: String?
    ) {
        self.id = id
        self.anniversary = anniversary
        self.date = date
        self.isFallback = isFallback
        self.fallbackNote = fallbackNote
        self.count = count
        self.countText = countText
    }
}

public enum AnniversaryResolver {
    public static let maximumLunarYearSearch = 120

    public static func nextOccurrence(
        for anniversary: Anniversary,
        onOrAfter referenceDate: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> AnniversaryOccurrence? {
        guard anniversary.isValid else { return nil }

        var searchCalendar = calendar
        searchCalendar.timeZone = LunarCalendar.timeZone
        let today = searchCalendar.startOfDay(for: referenceDate)

        switch anniversary.calendar {
        case .solar:
            let components = anniversary.solarDate ?? DateComponents()
            guard let originalYear = components.year,
                  let originalMonth = components.month,
                  let originalDay = components.day else { return nil }
            let currentYear = searchCalendar.component(.year, from: today)
            let candidateYears = [currentYear, currentYear + 1]
            for year in candidateYears {
                let components = DateComponents(year: year, month: originalMonth, day: originalDay)
                guard let date = searchCalendar.date(from: components) else { continue }
                if searchCalendar.startOfDay(for: date) >= today {
                    return makeOccurrence(
                        anniversary: anniversary,
                        date: date,
                        isFallback: false,
                        fallbackNote: nil,
                        count: count(fromOriginalYear: originalYear, toOccurrenceYear: year),
                        calendar: searchCalendar
                    )
                }
            }
            return nil

        case .lunar:
            guard let spec = anniversary.lunarDate else { return nil }
            let currentLunarYear = LunarCalendar.lunar(from: today).year
            for offset in 0..<maximumLunarYearSearch {
                let lunarYear = currentLunarYear + offset
                guard let result = candidateDate(
                    spec: spec,
                    lunarYear: lunarYear,
                    fallback: anniversary.leapMonthFallback
                ) else { continue }

                if searchCalendar.startOfDay(for: result.date) >= today {
                    return makeOccurrence(
                        anniversary: anniversary,
                        date: result.date,
                        isFallback: result.isFallback,
                        fallbackNote: result.note,
                        count: count(fromOriginalYear: spec.originalYear, toOccurrenceYear: lunarYear),
                        calendar: searchCalendar
                    )
                }
            }
            return nil
        }
    }

    public static func isOn(
        _ occurrence: AnniversaryOccurrence,
        day: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Bool {
        var searchCalendar = calendar
        searchCalendar.timeZone = LunarCalendar.timeZone
        return searchCalendar.isDate(occurrence.date, inSameDayAs: day)
    }

    static func candidateDate(
        spec: LunarDateSpec,
        lunarYear: Int,
        fallback: LeapMonthFallback
    ) -> (date: Date, isFallback: Bool, note: String?)? {
        let actualLeapMonth = LunarCalendar.leapMonth(of: lunarYear)
        let requestsLeap = spec.isLeapMonth

        if requestsLeap && actualLeapMonth == spec.month {
            return date(
                LunarDate(year: lunarYear, month: spec.month, day: spec.day, isLeapMonth: true),
                isFallback: false,
                note: nil
            )
        }

        if !requestsLeap {
            return date(
                LunarDate(year: lunarYear, month: spec.month, day: spec.day),
                isFallback: false,
                note: nil
            )
        }

        switch fallback {
        case .previousCommonMonth:
            return date(
                LunarDate(year: lunarYear, month: spec.month, day: spec.day),
                isFallback: true,
                note: "该年无闰\(LunarCalendar.monthNames[spec.month])，已按普通\(LunarCalendar.monthNames[spec.month])显示"
            )
        case .nextCommonMonth:
            guard spec.month < 12 else { return nil }
            return date(
                LunarDate(year: lunarYear, month: spec.month + 1, day: spec.day),
                isFallback: true,
                note: "该年无闰\(LunarCalendar.monthNames[spec.month])，已顺延为\(LunarCalendar.monthNames[spec.month + 1])"
            )
        case .skipYear:
            return nil
        }
    }

    private static func date(
        _ lunarDate: LunarDate,
        isFallback: Bool,
        note: String?
    ) -> (date: Date, isFallback: Bool, note: String?)? {
        guard let date = LunarCalendar.solar(from: lunarDate) else { return nil }
        return (date, isFallback, note)
    }

    private static func count(fromOriginalYear originalYear: Int?, toOccurrenceYear occurrenceYear: Int) -> Int? {
        guard let originalYear else { return nil }
        return occurrenceYear - originalYear
    }

    private static func makeOccurrence(
        anniversary: Anniversary,
        date: Date,
        isFallback: Bool,
        fallbackNote: String?,
        count: Int?,
        calendar: Calendar
    ) -> AnniversaryOccurrence {
        let countText: String?
        switch anniversary.kind {
        case .birthday:
            countText = anniversary.showAge ? count.map { "\($0) 岁" } : nil
        case .wedding, .memorial, .custom:
            countText = anniversary.showAnniversaryYears ? count.map { "第 \($0) 年" } : nil
        }

        return AnniversaryOccurrence(
            id: anniversary.id,
            anniversary: anniversary,
            date: calendar.startOfDay(for: date),
            isFallback: isFallback,
            fallbackNote: fallbackNote,
            count: count,
            countText: countText
        )
    }
}
