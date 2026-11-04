import XCTest
@testable import EventSearchKit

final class EventSearchKitTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDefaultQueryRangeAndKeywordTrimming() {
        let reference = date(2026, 11, 4)
        let query = EventSearchQuery(keyword:  " 会议 " )
        let resolved = query.resolvedInterval(referenceDate: reference, calendar: calendar)

        XCTAssertEqual(query.trimmedKeyword, "会议")
        XCTAssertTrue(query.canSearch)
        XCTAssertEqual(resolved.interval.start, calendar.date(byAdding: .day, value: -180, to: reference))
        XCTAssertEqual(resolved.interval.end, calendar.date(byAdding: .day, value: 365, to: reference))
        XCTAssertFalse(resolved.wasCapped)
    }

    func testPresetRanges() {
        let reference = date(2026, 11, 4)
        let cases: [(EventSearchRange, Int, Int)] = [
            (.next7Days, 0, 7),
            (.next30Days, 0, 30),
            (.pastAndNext90Days, -90, 90)
        ]

        for (range, startOffset, endOffset) in cases {
            let resolved = EventSearchQuery(keyword: "会议", range: range)
                .resolvedInterval(referenceDate: reference, calendar: calendar)
            XCTAssertEqual(
                resolved.interval.start,
                calendar.date(byAdding: .day, value: startOffset, to: reference)
            )
            XCTAssertEqual(
                resolved.interval.end,
                calendar.date(byAdding: .day, value: endOffset, to: reference)
            )
        }
    }

    func testCustomRangeNormalizesOrderAndCapsTo730Days() {
        let start = date(2026, 1, 1)
        let end = date(2029, 1, 1)
        let resolved = EventSearchQuery(
            keyword: "会议",
            range: .custom(start: end, end: start)
        ).resolvedInterval(referenceDate: Date(), calendar: calendar)

        XCTAssertEqual(resolved.interval.start, start)
        XCTAssertGreaterThan(resolved.interval.end, start)
        XCTAssertTrue(resolved.wasCapped)
        XCTAssertEqual(
            resolved.interval.duration,
            730 * 24 * 60 * 60,
            accuracy: 1
        )
    }

    func testRecentSearchDeduplicatesMovesToFrontAndCapsEight() throws {
        let defaults = UserDefaults(suiteName: "event-search-kit-tests")!
        defaults.removePersistentDomain(forName: "event-search-kit-tests")
        let store = RecentSearchStore(defaults: defaults)
        let range = EventSearchRange.next7Days

        store.save(keyword: "旧词", range: range)
        store.save(keyword: "会议", range: range)
        store.save(keyword: "会议", range: range)
        for index in 0..<10 {
            store.save(keyword: "关键词\(index)", range: range)
        }
        store.save(keyword: "会议", range: range)

        let items = store.load()
        XCTAssertEqual(items.count, RecentSearchStore.maximumCount)
        XCTAssertEqual(items.first?.keyword, "会议")
        XCTAssertFalse(items.contains { $0.keyword == "旧词" })
        XCTAssertEqual(items.filter { $0.keyword == "会议" }.count, 1)

        let first = try XCTUnwrap(items.first)
        store.remove(first)
        XCTAssertFalse(store.load().contains { $0.id == first.id })
    }
}
