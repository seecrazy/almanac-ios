import EventKit
import XCTest
@testable import EventKitMapping

final class EventRecurrenceMappingTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10, minute: Int = 30) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testCalendarNameIsTrimmedAndValidated() {
        XCTAssertEqual(
            CalendarManagementPolicy.normalizedTitle("  宜历工作  "),
            .success("宜历工作")
        )
        XCTAssertEqual(CalendarManagementPolicy.normalizedTitle("   "), .failure(.empty))
        XCTAssertEqual(
            CalendarManagementPolicy.normalizedTitle(String(repeating: "历", count: 65)),
            .failure(.tooLong)
        )
    }

    func testOnlyLocalModifiableCalendarsCanBeManaged() {
        XCTAssertTrue(CalendarManagementPolicy.canManageCalendar(
            isLocal: true,
            allowsContentModifications: true
        ))
        XCTAssertFalse(CalendarManagementPolicy.canManageCalendar(
            isLocal: false,
            allowsContentModifications: true
        ))
        XCTAssertFalse(CalendarManagementPolicy.canManageCalendar(
            isLocal: true,
            allowsContentModifications: false
        ))
    }

    func testDailyIntervalAndCountRoundTrip() throws {
        let start = date(2026, 11, 3)
        let draft = EventRecurrenceDraft(
            mode: .daily,
            interval: 3,
            endMode: .afterCount,
            endDate: start,
            occurrenceCount: 4
        )
        let rule = try XCTUnwrap(draft.makeRule(startDate: start))

        XCTAssertEqual(rule.frequency, .daily)
        XCTAssertEqual(rule.interval, 3)
        XCTAssertEqual(rule.recurrenceEnd?.occurrenceCount, 4)

        let parsed = try XCTUnwrap(EventRecurrenceDraft(rules: [rule], startDate: start))
        XCTAssertEqual(parsed.mode, .daily)
        XCTAssertEqual(parsed.interval, 3)
        XCTAssertEqual(parsed.endMode, .afterCount)
        XCTAssertEqual(parsed.occurrenceCount, 4)
    }

    func testWeeklyMultipleWeekdaysAndUntilRoundTrip() throws {
        let start = date(2026, 11, 4)
        let end = date(2026, 12, 31)
        let draft = EventRecurrenceDraft(
            mode: .weekly,
            weekdays: [3, 6],
            endMode: .onDate,
            endDate: end
        )
        let rule = try XCTUnwrap(draft.makeRule(startDate: start))

        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 1)
        XCTAssertEqual(Set(rule.daysOfTheWeek?.map(\.dayOfTheWeek.rawValue) ?? []), [3, 6])
        XCTAssertNotNil(rule.recurrenceEnd?.endDate)

        let parsed = try XCTUnwrap(EventRecurrenceDraft(rules: [rule], startDate: start))
        XCTAssertEqual(parsed.mode, .weekly)
        XCTAssertEqual(parsed.weekdays, [3, 6])
        XCTAssertEqual(parsed.endMode, .onDate)
    }

    func testMonthlyNthWeekdayRoundTrip() throws {
        let start = date(2026, 11, 4)
        let draft = EventRecurrenceDraft(
            mode: .monthly,
            monthlyRule: .nthWeekday(week: 2, weekday: 4),
            endMode: .never,
            endDate: start
        )
        let rule = try XCTUnwrap(draft.makeRule(startDate: start))

        XCTAssertEqual(rule.frequency, .monthly)
        XCTAssertEqual(rule.daysOfTheWeek?.first?.weekNumber, 2)
        XCTAssertEqual(rule.daysOfTheWeek?.first?.dayOfTheWeek, .wednesday)

        let parsed = try XCTUnwrap(EventRecurrenceDraft(rules: [rule], startDate: start))
        XCTAssertEqual(parsed.monthlyRule, .nthWeekday(week: 2, weekday: 4))
    }

    func testUnsupportedRuleBecomesProtected() throws {
        let start = date(2026, 11, 4)
        let rule = EKRecurrenceRule(
            recurrenceWith: .monthly,
            interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.wednesday)],
            daysOfTheMonth: [],
            monthsOfTheYear: [],
            weeksOfTheYear: [],
            daysOfTheYear: [],
            setPositions: [NSNumber(value: -1)],
            end: nil
        )
        let parsed = try XCTUnwrap(EventRecurrenceDraft(rules: [rule], startDate: start))

        XCTAssertEqual(parsed.mode, .preserveExisting)
        XCTAssertNil(parsed.makeRule(startDate: start))
    }

    func testPreviewShowsFirstThreeOccurrences() {
        let start = date(2026, 11, 4)
        let draft = EventRecurrenceDraft(
            mode: .weekly,
            weekdays: [4],
            endMode: .never,
            endDate: start
        )
        let occurrences = draft.previewOccurrences(startDate: start)

        XCTAssertEqual(occurrences.count, 3)
        XCTAssertEqual(occurrences[0], start)
        XCTAssertEqual(occurrences[1], date(2026, 11, 11))
        XCTAssertEqual(occurrences[2], date(2026, 11, 18))
    }

    func testInvalidEditorStateCannotMakeRule() {
        let start = date(2026, 11, 4)
        let emptyWeekdays = EventRecurrenceDraft(
            mode: .weekly,
            weekdays: [],
            endMode: .never,
            endDate: start
        )
        XCTAssertFalse(emptyWeekdays.canRepresent(startDate: start))
        XCTAssertNil(emptyWeekdays.makeRule(startDate: start))

        let invalidCount = EventRecurrenceDraft(
            mode: .daily,
            endMode: .afterCount,
            endDate: start,
            occurrenceCount: 0
        )
        XCTAssertFalse(invalidCount.canRepresent(startDate: start))
    }
}
