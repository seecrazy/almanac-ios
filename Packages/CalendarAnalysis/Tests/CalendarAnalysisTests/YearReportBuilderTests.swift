import XCTest
@testable import CalendarAnalysis

final class YearReportBuilderTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func event(
        _ id: String,
        title: String = "事件",
        calendarTitle: String = "工作",
        _ start: Date,
        _ end: Date,
        isAllDay: Bool = false
    ) -> YearReportEvent {
        YearReportEvent(
            id: id, title: title, calendarTitle: calendarTitle,
            startDate: start, endDate: end, isAllDay: isAllDay
        )
    }

    func testEmptyYearProducesZeroReport() {
        let report = YearReportBuilder.build(year: 2026, events: [])
        XCTAssertEqual(report.timedEventCount, 0)
        XCTAssertEqual(report.totalHours, 0)
        XCTAssertNil(report.longestEventTitle)
        XCTAssertNil(report.busiestMonth)
        XCTAssertNil(report.topCalendarTitle)
    }

    func testCountsDurationsAndLongestEvent() {
        let events = [
            event("a", title: "短会", date(2026, 3, 5, hour: 9), date(2026, 3, 5, hour: 10)),
            event("b", title: "全天", date(2026, 3, 6), date(2026, 3, 7), isAllDay: true),
            event("c", title: "长工作坊", date(2026, 6, 10, hour: 9), date(2026, 6, 10, hour: 18))
        ]

        let report = YearReportBuilder.build(year: 2026, events: events, calendar: calendar)

        XCTAssertEqual(report.timedEventCount, 2)
        XCTAssertEqual(report.allDayEventCount, 1)
        XCTAssertEqual(report.totalHours, 10, accuracy: 0.001)
        XCTAssertEqual(report.longestEventTitle, "长工作坊")
        XCTAssertEqual(report.longestEventHours, 9, accuracy: 0.001)
    }

    func testCrossYearDurationClippedToYear() {
        // 2025-12-31 22:00 → 2026-01-01 02:00：2026 年内只计 2 小时。
        let events = [
            event("x", date(2025, 12, 31, hour: 22), date(2026, 1, 1, hour: 2))
        ]

        let report = YearReportBuilder.build(year: 2026, events: events, calendar: calendar)

        XCTAssertEqual(report.timedEventCount, 1)
        XCTAssertEqual(report.totalHours, 2, accuracy: 0.001)
    }

    func testEventsOutsideYearIgnored() {
        let events = [
            event("old", date(2025, 3, 5, hour: 9), date(2025, 3, 5, hour: 10)),
            event("next", date(2027, 3, 5, hour: 9), date(2027, 3, 5, hour: 10))
        ]

        let report = YearReportBuilder.build(year: 2026, events: events, calendar: calendar)
        XCTAssertEqual(report.timedEventCount, 0)
    }

    func testBusiestMonthWeekdayAndTopCalendar() {
        let events = [
            event("1", calendarTitle: "工作", date(2026, 11, 2, hour: 9), date(2026, 11, 2, hour: 10)), // 周一
            event("2", calendarTitle: "工作", date(2026, 11, 9, hour: 9), date(2026, 11, 9, hour: 10)), // 周一
            event("3", calendarTitle: "生活", date(2026, 3, 4, hour: 9), date(2026, 3, 4, hour: 10)),
            event("4", calendarTitle: "生活", date(2026, 11, 11, hour: 9), date(2026, 11, 11, hour: 10)) // 周三
        ]

        let report = YearReportBuilder.build(year: 2026, events: events, calendar: calendar)

        XCTAssertEqual(report.busiestMonth, 11)
        XCTAssertEqual(report.busiestMonthCount, 3)
        XCTAssertEqual(report.busiestWeekday, "周一")
        XCTAssertEqual(report.busiestWeekdayCount, 2)
        XCTAssertEqual(report.topCalendarTitle, "工作")
        XCTAssertEqual(report.monthCounts[10], 3)
        XCTAssertEqual(report.monthCounts[2], 1)
    }

    func testSummaryTextContainsKeyLines() {
        let events = [
            event("a", title: "冲刺", date(2026, 5, 20, hour: 9), date(2026, 5, 20, hour: 12))
        ]
        let report = YearReportBuilder.build(
            year: 2026,
            events: events,
            upcomingMilestones: 3,
            pastMilestones: 1,
            calendar: calendar
        )

        XCTAssertTrue(report.summaryText.contains("2026 年度回顾"))
        XCTAssertTrue(report.summaryText.contains("冲刺"))
        XCTAssertTrue(report.summaryText.contains("进行中 3"))
    }
}
