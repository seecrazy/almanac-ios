import Foundation
import HolidayData

/// 节假日数据协调器（ADR-013）：内置兜底 + 联网更新。
/// - 激活时自动检查（24h 节流），设置页可手动强制；
/// - 数据源：GitHub raw 主源 + jsdelivr 备源（holiday-cn 数据集，MIT）；
/// - 校验通过的年度数据覆盖同年内置值并持久化，失败静默回退内置。
@MainActor
final class HolidayDataCoordinator: ObservableObject {
    enum UpdateState: Equatable {
        case idle
        case checking
        case updated(years: [Int])
        case upToDate
        case failed(String)
    }

    @Published private(set) var store: HolidayStore
    @Published private(set) var updateState: UpdateState = .idle

    private let defaults: UserDefaults
    private let session: URLSession
    private let lastCheckKey = "holiday.remote.lastCheck"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    static func defaultCacheDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HolidayRemote", isDirectory: true)
    }

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        self.store = Self.loadMerged(cacheDirectory: Self.defaultCacheDirectory())
    }

    /// 启动合并：磁盘缓存的远程年度 + 内置。
    static func loadMerged(cacheDirectory: URL) -> HolidayStore {
        let years = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let remote = years
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> HolidayYear? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return HolidayStore.decodeFromCache(data)
            }
        return remote.isEmpty ? .bundledShared : .bundledWithRemote(remote)
    }

    /// 激活时调用：24 小时节流；`force = true` 跳过节流（设置页手动）。
    func checkForUpdates(force: Bool = false) async {
        if !force,
           let last = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        defaults.set(Date(), forKey: lastCheckKey)

        updateState = .checking
        let currentYear = Calendar.current.component(.year, from: Date())
        let allowed: Set<Int> = [currentYear, currentYear + 1]

        var fetched: [HolidayYear] = []
        for year in allowed.sorted() {
            if let yearModel = await fetchYear(year, allowed: allowed) {
                fetched.append(yearModel)
            }
        }

        guard !fetched.isEmpty else {
            updateState = .failed("暂无法获取更新（网络不可用或数据校验未通过），继续使用内置数据")
            return
        }

        let (changed, newRemote) = persist(fetched)
        if changed {
            store = Self.loadMerged(cacheDirectory: Self.defaultCacheDirectory())
            updateState = .updated(years: fetched.map(\.year))
        } else {
            updateState = .upToDate
        }
        _ = newRemote
    }

    private func fetchYear(_ year: Int, allowed: Set<Int>) async -> HolidayYear? {
        let endpoints = [
            "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json",
            "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json"
        ]
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else {
                continue
            }
            if let validated = try? HolidayRemoteUpdate.validatedYear(from: data, allowedYears: allowed) {
                return validated
            }
        }
        return nil
    }

    /// 落盘并返回（是否有变化, 全部远程年度）。已有相同内容时跳过写盘。
    private func persist(_ fetched: [HolidayYear]) -> (changed: Bool, all: [HolidayYear]) {
        let cacheDirectory = Self.defaultCacheDirectory()
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        var changed = false

        for year in fetched {
            let url = cacheDirectory.appendingPathComponent("\(year.year).json")
            let existing = (try? Data(contentsOf: url)).flatMap(HolidayStore.decodeFromCache)
            if existing == year { continue }
            if let data = HolidayStore.encodeForCache(year) {
                try? data.write(to: url, options: .atomic)
                changed = true
            }
        }
        return (changed, fetched)
    }
}
