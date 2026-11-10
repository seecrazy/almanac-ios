import Foundation

/// holiday-cn 远程数据集的原始格式（NateScarlet/holiday-cn，MIT）。
/// 仅作解析与校验用；网络请求在 App 层。
public struct RemoteHolidayDataset: Codable, Equatable {
    public struct Day: Codable, Equatable {
        public let name: String
        /// yyyy-MM-dd
        public let date: String
        public let isOffDay: Bool
    }

    public let year: Int
    public let papers: [String]?
    public let days: [Day]
}

public enum RemoteHolidayValidationError: Error, Equatable, CustomStringConvertible {
    case emptyDays
    case yearOutOfRange(Int)
    case invalidDate(String)
    case dateOutsideYear(date: String, year: Int)
    case duplicateDate(String)
    case emptyName(String)
    case tooFewOffDays(Int)
    case tooManyDays(Int)

    public var description: String {
        switch self {
        case .emptyDays: return "远程数据为空"
        case .yearOutOfRange(let year): return "年份 \(year) 超出允许范围"
        case .invalidDate(let date): return "非法日期 \(date)"
        case .dateOutsideYear(let date, let year): return "日期 \(date) 不在 \(year) 年内"
        case .duplicateDate(let date): return "重复日期 \(date)"
        case .emptyName(let date): return "日期 \(date) 的节日名为空"
        case .tooFewOffDays(let count): return "休日仅 \(count) 天，可疑"
        case .tooManyDays(let count): return "总天数 \(count) 超限，可疑"
        }
    }
}

public enum HolidayRemoteUpdate {
    public static let maximumDays = 80
    public static let minimumOffDays = 5

    /// 解析 + 校验 + 转换为内部 HolidayYear（source 固定 official）。
    /// - Parameters:
    ///   - data: 数据集原始 JSON。
    ///   - allowedYears: 允许接受的年份集合（App 层传 {当前年, 当前年+1}）。
    public static func validatedYear(
        from data: Data,
        allowedYears: Set<Int>
    ) throws -> HolidayYear {
        guard let dataset = try? JSONDecoder().decode(RemoteHolidayDataset.self, from: data) else {
            throw RemoteHolidayValidationError.emptyDays
        }
        return try validatedYear(from: dataset, allowedYears: allowedYears)
    }

    public static func validatedYear(
        from dataset: RemoteHolidayDataset,
        allowedYears: Set<Int>
    ) throws -> HolidayYear {
        guard allowedYears.contains(dataset.year) else {
            throw RemoteHolidayValidationError.yearOutOfRange(dataset.year)
        }
        guard !dataset.days.isEmpty else {
            throw RemoteHolidayValidationError.emptyDays
        }
        guard dataset.days.count <= maximumDays else {
            throw RemoteHolidayValidationError.tooManyDays(dataset.days.count)
        }

        var seenDates = Set<String>()
        var offDays = 0
        let yearPrefix = "\(dataset.year)-"
        for day in dataset.days {
            guard day.date.hasPrefix(yearPrefix), day.date.count == 10 else {
                throw day.date.hasPrefix(yearPrefix)
                    ? RemoteHolidayValidationError.invalidDate(day.date)
                    : RemoteHolidayValidationError.dateOutsideYear(date: day.date, year: dataset.year)
            }
            guard Self.isLexicallyValidDate(day.date) else {
                throw RemoteHolidayValidationError.invalidDate(day.date)
            }
            guard seenDates.insert(day.date).inserted else {
                throw RemoteHolidayValidationError.duplicateDate(day.date)
            }
            guard !day.name.isEmpty else {
                throw RemoteHolidayValidationError.emptyName(day.date)
            }
            if day.isOffDay { offDays += 1 }
        }
        guard offDays >= minimumOffDays else {
            throw RemoteHolidayValidationError.tooFewOffDays(offDays)
        }

        // 按节日名分组转换为内部结构。
        var groups: [String: (daysOff: [String], workdays: [String])] = [:]
        for day in dataset.days {
            var group = groups[day.name] ?? ([], [])
            if day.isOffDay {
                group.daysOff.append(day.date)
            } else {
                group.workdays.append(day.date)
            }
            groups[day.name] = group
        }

        let note = "国务院办公厅通知（holiday-cn 数据集）"
        return HolidayYear(
            year: dataset.year,
            source: .official,
            note: note,
            holidays: groups
                .map { HolidayGroup(name: $0.key, daysOff: $0.value.daysOff.sorted(), workdays: $0.value.workdays.sorted()) }
                .sorted { $0.daysOff.first ?? "" < $1.daysOff.first ?? "" }
        )
    }

    /// yyyy-MM-dd 的词法校验（月份 01–12、日期 01–31，足够拦截结构错误）。
    static func isLexicallyValidDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let month = Int(parts[1]), let day = Int(parts[2]) else {
            return false
        }
        return (1...12).contains(month) && (1...31).contains(day)
    }
}

public extension HolidayStore {
    /// 内置数据 + 远程覆盖（同年替换，他年保留）。任一年度校验失败即整体回退纯内置。
    /// 持久化由 App 层负责（把 HolidayYear 编码为 JSON 落盘，启动时读回传入）。
    static func bundledWithRemote(_ remoteYears: [HolidayYear]) -> HolidayStore {
        guard !remoteYears.isEmpty else { return .bundledShared }

        guard let manifestURL = Bundle.module.url(forResource: "holiday-manifest", withExtension: "json"),
              let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(HolidayManifest.self, from: manifestData) else {
            return HolidayStore(holidays: [])
        }

        // 内置年度解码（单个损坏跳过）。
        var years: [Int: HolidayYear] = [:]
        for entry in manifest.years {
            let fileURL = URL(fileURLWithPath: entry.file)
            let resource = fileURL.deletingPathExtension().lastPathComponent
            let fileExtension = fileURL.pathExtension
            guard let url = Bundle.module.url(forResource: resource, withExtension: fileExtension),
                  let data = try? Data(contentsOf: url),
                  let year = try? JSONDecoder().decode(HolidayYear.self, from: data) else {
                continue
            }
            years[year.year] = year
        }

        for remote in remoteYears {
            years[remote.year] = remote
        }

        let store = try? HolidayStore(years: years.values.sorted { $0.year < $1.year })
        return store ?? .bundledShared
    }

    /// 编码远程年度数据供 App 层落盘（与 bundledWithRemote 配套的往返格式）。
    static func encodeForCache(_ year: HolidayYear) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(year)
    }

    static func decodeFromCache(_ data: Data) -> HolidayYear? {
        try? JSONDecoder().decode(HolidayYear.self, from: data)
    }
}
