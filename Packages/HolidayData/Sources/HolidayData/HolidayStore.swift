import Foundation

/// 数据来源。UI 必须区分官方数据与示例 / 预测数据。
public enum HolidaySource: String, Codable, CaseIterable, Equatable {
    case official
    case sample
    case estimated

    public var title: String {
        switch self {
        case .official: return "官方数据"
        case .sample: return "示例数据"
        case .estimated: return "预测数据"
        }
    }
}

/// 某天的节假日效果
public enum DayEffect: Equatable {
    case restDay(name: String)   // 法定休：名称（如“春节”）
    case workday(name: String)   // 调休补班：所属节日名
}

/// 年度放假安排（JSON 反序列化模型）
public struct HolidayYear: Codable, Equatable {
    public let year: Int
    public let source: HolidaySource
    public let note: String?
    public let holidays: [HolidayGroup]
}

public struct HolidayGroup: Codable, Equatable {
    public let name: String
    public let daysOff: [String]     // yyyy-MM-dd
    public let workdays: [String]    // 调休补班日
}

public struct HolidayManifest: Codable, Equatable {
    public let version: Int
    public let years: [HolidayManifestEntry]
}

public struct HolidayManifestEntry: Codable, Equatable {
    public let year: Int
    public let file: String
    public let source: HolidaySource
    public let sourceName: String?
    public let sourceURL: String?
    public let issuedAt: String?
}

public struct HolidayYearStatus: Equatable {
    public let year: Int
    public let source: HolidaySource
    public let sourceName: String?
    public let issuedAt: String?
    public let note: String?
}

public enum HolidayCoverage: Equatable {
    case covered
    case noSpecialDay
    case yearNotLoaded
    case unknown
}

public enum HolidayDataError: Error, Equatable {
    case duplicateDay(year: Int, day: String)
    case conflictingDay(year: Int, day: String)
    case invalidDate(year: Int, day: String)
    case duplicateGroupName(year: Int, name: String)
    case missingRequiredHoliday(year: Int)
    case sourceMismatch(year: Int, manifest: HolidaySource, yearFile: HolidaySource)
    case unsupportedManifestVersion(Int)
    case duplicateManifestYear(Int)
}

/// 节假日查询引擎：数据与算法分离，年度 JSON 与 manifest 可独立更新（ADR-007）
public final class HolidayStore {
    private var years: [Int: HolidayYear] = [:]
    private var manifestEntries: [Int: HolidayManifestEntry] = [:]
    private var restDays: [String: String] = [:]
    private var workdays: [String: String] = [:]
    private var coverageKnown = false

    public private(set) var statuses: [HolidayYearStatus] = []
    public private(set) var loadErrors: [String] = []

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = LunarCalendarShanghai.timezone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let yearCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = LunarCalendarShanghai.timezone
        return calendar
    }()

    /// 兼容旧调用：只接收节假日组，不提供年度来源与覆盖状态。
    public init(holidays: [HolidayGroup]) {
        for group in holidays {
            for day in group.daysOff { restDays[day] = group.name }
            for day in group.workdays { workdays[day] = group.name }
        }
    }

    /// 从一个或多个年度 JSON 构建可判断覆盖状态的查询库。
    public init(years annualYears: [HolidayYear]) throws {
        coverageKnown = true
        try annualYears.forEach { try insert($0, manifestEntry: nil) }
        refreshStatuses()
    }

    public convenience init(json: Data) throws {
        let year = try JSONDecoder().decode(HolidayYear.self, from: json)
        try self.init(years: [year])
    }

    /// 从 manifest 构建默认查询库。单个年度损坏时跳过并记录，不影响其他年度。
    public init(manifest: HolidayManifest, yearData: [Int: Data]) {
        coverageKnown = true

        do {
            try Self.validateManifest(manifest)
        } catch {
            loadErrors.append(String(describing: error))
            return
        }

        for entry in manifest.years {
            guard let data = yearData[entry.year] else {
                loadErrors.append("HolidayData: \(entry.file) is missing")
                continue
            }

            do {
                let year = try JSONDecoder().decode(HolidayYear.self, from: data)
                try insert(year, manifestEntry: entry)
            } catch {
                loadErrors.append("\(entry.file): \(error)")
            }
        }

        refreshStatuses()
    }

    /// 某天的法定效果（nil = 非法定特殊日）
    public func effect(for date: Date) -> DayEffect? {
        let key = Self.keyFormatter.string(from: date)
        if let name = restDays[key] { return .restDay(name: name) }
        if let name = workdays[key] { return .workday(name: name) }
        return nil
    }

    /// 某天所属年度的数据来源；年度未加载时为 nil。
    public func source(for date: Date) -> HolidaySource? {
        let year = Self.yearCalendar.component(.year, from: date)
        return years[year]?.source
    }

    /// 年度状态；仅已成功加载的年度返回值。
    public func status(for year: Int) -> HolidayYearStatus? {
        years[year].map { loadedYear in
            Self.status(for: loadedYear, manifestEntry: manifestEntries[loadedYear.year])
        }
    }

    /// 覆盖状态用于 UI 判断是否展示休/班、普通日或未覆盖提示。
    public func coverage(for date: Date) -> HolidayCoverage {
        guard coverageKnown else { return .unknown }
        let year = Self.yearCalendar.component(.year, from: date)
        guard years[year] != nil else { return .yearNotLoaded }
        return effect(for: date) == nil ? .noSpecialDay : .covered
    }

    /// 指定日期之后的下一个法定假日，可跨已加载年度。
    public func nextHoliday(after date: Date) -> (date: Date, name: String)? {
        let currentKey = Self.keyFormatter.string(from: date)
        for key in restDays.keys.sorted() where key > currentKey {
            if let day = Self.keyFormatter.date(from: key), let name = restDays[key] {
                return (day, name)
            }
        }
        return nil
    }

    private func insert(_ year: HolidayYear, manifestEntry: HolidayManifestEntry?) throws {
        if years[year.year] != nil {
            throw HolidayDataError.duplicateManifestYear(year.year)
        }

        let entries = try Self.validatedEntries(for: year)
        if let manifestEntry, manifestEntry.source != year.source {
            throw HolidayDataError.sourceMismatch(
                year: year.year,
                manifest: manifestEntry.source,
                yearFile: year.source
            )
        }

        years[year.year] = year
        if let manifestEntry { manifestEntries[year.year] = manifestEntry }
        entries.rest.forEach { restDays[$0.key] = $0.value }
        entries.work.forEach { workdays[$0.key] = $0.value }
    }

    private func refreshStatuses() {
        statuses = years.values
            .map { Self.status(for: $0, manifestEntry: manifestEntries[$0.year]) }
            .sorted { $0.year < $1.year }
    }

    private static func status(
        for year: HolidayYear,
        manifestEntry: HolidayManifestEntry?
    ) -> HolidayYearStatus {
        HolidayYearStatus(
            year: year.year,
            source: year.source,
            sourceName: manifestEntry?.sourceName,
            issuedAt: manifestEntry?.issuedAt,
            note: year.note
        )
    }

    private static func validateManifest(_ manifest: HolidayManifest) throws {
        guard manifest.version == 1 else {
            throw HolidayDataError.unsupportedManifestVersion(manifest.version)
        }

        var seenYears = Set<Int>()
        for entry in manifest.years {
            guard !seenYears.contains(entry.year) else {
                throw HolidayDataError.duplicateManifestYear(entry.year)
            }
            seenYears.insert(entry.year)
        }
    }

    private static func validatedEntries(for year: HolidayYear) throws
        -> (rest: [String: String], work: [String: String]) {
        var rest: [String: String] = [:]
        var work: [String: String] = [:]
        var groupNames = Set<String>()

        for group in year.holidays {
            guard !groupNames.contains(group.name) else {
                throw HolidayDataError.duplicateGroupName(year: year.year, name: group.name)
            }
            groupNames.insert(group.name)

            for day in group.daysOff {
                try validate(day: day, in: year.year)
                if rest[day] != nil || work[day] != nil {
                    throw HolidayDataError.conflictingDay(year: year.year, day: day)
                }
                rest[day] = group.name
            }

            for day in group.workdays {
                try validate(day: day, in: year.year)
                if rest[day] != nil || work[day] != nil {
                    throw HolidayDataError.conflictingDay(year: year.year, day: day)
                }
                work[day] = group.name
            }
        }

        if year.source == .official {
            let requiredNames = ["春节", "国庆", "劳动节"]
            let hasRequiredHoliday = year.holidays.contains { group in
                requiredNames.contains { group.name.contains($0) }
            }
            guard hasRequiredHoliday else {
                throw HolidayDataError.missingRequiredHoliday(year: year.year)
            }
        }

        return (rest, work)
    }

    private static func validate(day: String, in year: Int) throws {
        guard let date = keyFormatter.date(from: day),
              yearCalendar.component(.year, from: date) == year,
              keyFormatter.string(from: date) == day else {
            throw HolidayDataError.invalidDate(year: year, day: day)
        }
    }
}

/// 与 LunarKit 相同的时区语义（独立声明以保持本包零依赖）
public enum LunarCalendarShanghai {
    public static let timezone = TimeZone(identifier: "Asia/Shanghai")!
}

public extension HolidayStore {
    /// App 默认数据源：读取 manifest 与其中列出的年度 JSON。
    static func bundled(years requestedYears: ClosedRange<Int>? = nil) -> HolidayStore {
        #if SWIFTPM
        guard let manifestURL = Bundle.module.url(forResource: "holiday-manifest", withExtension: "json"),
              let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(HolidayManifest.self, from: manifestData) else {
            return HolidayStore(holidays: [])
        }

        let entries = manifest.years.filter { entry in
            requestedYears?.contains(entry.year) ?? true
        }
        let selectedManifest = HolidayManifest(version: manifest.version, years: entries)
        var annualData: [Int: Data] = [:]

        for entry in selectedManifest.years {
            let fileURL = URL(fileURLWithPath: entry.file)
            let resource = fileURL.deletingPathExtension().lastPathComponent
            let fileExtension = fileURL.pathExtension
            guard let url = Bundle.module.url(forResource: resource, withExtension: fileExtension),
                  let data = try? Data(contentsOf: url) else {
                continue
            }
            annualData[entry.year] = data
        }

        return HolidayStore(manifest: selectedManifest, yearData: annualData)
        #else
        return HolidayStore(holidays: [])
        #endif
    }
}
