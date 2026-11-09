import XCTest
@testable import Almanac

/// App 层纯逻辑测试：Spotlight 深链路由与共享格式化器。
@MainActor
final class AppRouterTests: XCTestCase {
    func testRoutesMilestoneIdentifierToCountdownTab() {
        let router = AppRouter()
        let id = UUID()

        router.handleSearchableItemActivity(identifier: "milestone.\(id.uuidString)")

        XCTAssertEqual(router.selectedTab, .countdown)
        XCTAssertEqual(router.pendingMilestoneID, id)
    }

    func testRoutesAnniversaryIdentifierToCountdownTab() {
        let router = AppRouter()
        let id = UUID()

        router.handleSearchableItemActivity(identifier: "anniversary.\(id.uuidString)")

        XCTAssertEqual(router.selectedTab, .countdown)
        XCTAssertEqual(router.pendingAnniversaryID, id)
    }

    func testRoutesDiaryIdentifierToCalendarTabWithParsedDate() {
        let router = AppRouter()

        router.handleSearchableItemActivity(identifier: "diary.2026-11-09")

        XCTAssertEqual(router.selectedTab, .calendar)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        XCTAssertEqual(
            router.pendingDiaryDate.map { calendar.dateComponents([.year, .month, .day], from: $0) },
            DateComponents(year: 2026, month: 11, day: 9)
        )
    }

    func testIgnoresUnknownIdentifiers() {
        let router = AppRouter()
        router.selectedTab = .alarm

        router.handleSearchableItemActivity(identifier: "unknown.abc")
        router.handleSearchableItemActivity(identifier: "diary.not-a-date")
        router.handleSearchableItemActivity(identifier: "milestone.not-uuid")

        XCTAssertEqual(router.selectedTab, .alarm)
        XCTAssertNil(router.pendingMilestoneID)
        XCTAssertNil(router.pendingAnniversaryID)
        XCTAssertNil(router.pendingDiaryDate)
    }

    func testSharedFormattersProduceExpectedPatterns() {
        // 取 UTC 正午，任何时区下月/日一致，测试环境无关。
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let noon = utc.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12))!

        XCTAssertEqual(AppFormatters.monthDay.string(from: noon), "11月9日")
        XCTAssertEqual(AppFormatters.fullDate.string(from: noon), "2026年11月9日")
        XCTAssertTrue(AppFormatters.fullDateWeekday.string(from: noon).hasPrefix("2026年11月9日"))
    }
}
