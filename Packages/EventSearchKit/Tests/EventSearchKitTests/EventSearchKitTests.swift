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

    private func dateTime(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func makeIndex() throws -> EventSearchIndex {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("event-search-index-\(UUID().uuidString)", isDirectory: true)
        return try EventSearchIndex(
            databaseURL: directory.appendingPathComponent("Index.sqlite")
        )
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

    func testSearchIndexFiltersAndOrdersEvents() throws {
        let index = try makeIndex()
        let records = [
            IndexedEventRecord(
                eventID: "all-day",
                calendarID: "work",
                title: "季度规划",
                location: nil,
                notes: nil,
                startDate: dateTime(2026, 11, 4, hour: 0),
                endDate: dateTime(2026, 11, 5, hour: 0),
                isAllDay: true
            ),
            IndexedEventRecord(
                eventID: "afternoon",
                calendarID: "work",
                title: "产品会议",
                location: "会议室 A",
                notes: nil,
                startDate: dateTime(2026, 11, 4, hour: 14),
                endDate: dateTime(2026, 11, 4, hour: 15),
                isAllDay: false
            ),
            IndexedEventRecord(
                eventID: "next-day",
                calendarID: "personal",
                title: "客户会议",
                location: nil,
                notes: "准备报价",
                startDate: dateTime(2026, 11, 5, hour: 9),
                endDate: dateTime(2026, 11, 5, hour: 10),
                isAllDay: false
            ),
            IndexedEventRecord(
                eventID: "outside",
                calendarID: "work",
                title: "周会",
                location: nil,
                notes: nil,
                startDate: dateTime(2026, 11, 10, hour: 9),
                endDate: dateTime(2026, 11, 10, hour: 10),
                isAllDay: false
            )
        ]
        try index.replaceAll(records)

        let interval = DateInterval(
            start: dateTime(2026, 11, 4, hour: 0),
            end: dateTime(2026, 11, 6, hour: 0)
        )
        let allResults = try index.search(
            keyword: "会议",
            interval: interval,
            calendarIDs: nil,
            includeAllDay: true
        )
        XCTAssertEqual(allResults.map(\.eventID), ["afternoon", "next-day"])

        let calendarFiltered = try index.search(
            keyword: "会议",
            interval: interval,
            calendarIDs: ["personal"],
            includeAllDay: true
        )
        XCTAssertEqual(calendarFiltered.map(\.eventID), ["next-day"])

        let emptyCalendarResults = try index.search(
            keyword: "会议",
            interval: interval,
            calendarIDs: [],
            includeAllDay: true
        )
        XCTAssertTrue(emptyCalendarResults.isEmpty)
    }

    func testSearchIndexMatchesFieldsAndEscapesQuerySyntax() throws {
        let index = try makeIndex()
        let start = dateTime(2026, 11, 4, hour: 9)
        let records = [
            IndexedEventRecord(
                eventID: "title",
                calendarID: "work",
                title: "产品会议",
                location: nil,
                notes: nil,
                startDate: start,
                endDate: start.addingTimeInterval(3600),
                isAllDay: false
            ),
            IndexedEventRecord(
                eventID: "location",
                calendarID: "work",
                title: "评审",
                location: "会议室 A",
                notes: nil,
                startDate: start.addingTimeInterval(3600),
                endDate: start.addingTimeInterval(7200),
                isAllDay: false
            ),
            IndexedEventRecord(
                eventID: "notes",
                calendarID: "work",
                title: "提醒",
                location: nil,
                notes: "会后整理会议纪要",
                startDate: start.addingTimeInterval(7200),
                endDate: start.addingTimeInterval(10800),
                isAllDay: false
            )
        ]
        try index.replaceAll(records)
        let interval = DateInterval(start: start, duration: 24 * 3600)

        XCTAssertEqual(try index.search(
            keyword: "产品",
            interval: interval,
            calendarIDs: nil,
            includeAllDay: true
        ).map(\.eventID), ["title"])
        XCTAssertEqual(try index.search(
            keyword: "会议室",
            interval: interval,
            calendarIDs: nil,
            includeAllDay: true
        ).map(\.eventID), ["location"])
        XCTAssertEqual(try index.search(
            keyword: "纪要",
            interval: interval,
            calendarIDs: nil,
            includeAllDay: true
        ).map(\.eventID), ["notes"])

        _ = try index.search(
            keyword: "\"会议\" OR *",
            interval: interval,
            calendarIDs: nil,
            includeAllDay: true
        )
    }

    func testSearchIndexReplaceAllClearsStaleRecordsAndLimitsResults() throws {
        let index = try makeIndex()
        let start = dateTime(2026, 11, 4, hour: 9)
        let oldRecord = IndexedEventRecord(
            eventID: "old",
            calendarID: "work",
            title: "旧会议",
            location: nil,
            notes: nil,
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            isAllDay: false
        )
        try index.replaceAll([oldRecord])
        XCTAssertEqual(index.recordCount, 1)

        let manyRecords = (0...200).map { number in
            IndexedEventRecord(
                eventID: "event-\(number)",
                calendarID: "work",
                title: "会议 \(number)",
                location: nil,
                notes: nil,
                startDate: start.addingTimeInterval(Double(number) * 60),
                endDate: start.addingTimeInterval(Double(number) * 60 + 600),
                isAllDay: false
            )
        }
        try index.replaceAll(manyRecords)

        XCTAssertEqual(index.recordCount, 201)
        XCTAssertEqual(try index.search(
            keyword: "会议",
            interval: DateInterval(start: start, duration: 24 * 3600),
            calendarIDs: nil,
            includeAllDay: true
        ).count, EventSearchIndex.resultLimit)
    }
}
