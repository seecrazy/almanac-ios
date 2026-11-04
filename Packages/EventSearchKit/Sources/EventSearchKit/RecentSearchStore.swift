import Foundation

public struct RecentSearchItem: Codable, Hashable, Identifiable {
    public let keyword: String
    public let range: EventSearchRange

    public var id: String {
        "\(keyword)|\(String(describing: range))"
    }

    public init(keyword: String, range: EventSearchRange) {
        self.keyword = keyword
        self.range = range
    }
}

public final class RecentSearchStore {
    public static let maximumCount = 8
    public let storageKey = "event.search.recent.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [RecentSearchItem] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([RecentSearchItem].self, from: data)) ?? []
    }

    public func save(keyword: String, range: EventSearchRange) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { return }

        let item = RecentSearchItem(keyword: trimmedKeyword, range: range)
        var items = load().filter { $0.id != item.id }
        items.insert(item, at: 0)
        persist(Array(items.prefix(Self.maximumCount)))
    }

    public func remove(_ item: RecentSearchItem) {
        persist(load().filter { $0.id != item.id })
    }

    private func persist(_ items: [RecentSearchItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
