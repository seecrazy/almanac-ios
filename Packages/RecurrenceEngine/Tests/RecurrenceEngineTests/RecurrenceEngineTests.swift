import XCTest
@testable import RecurrenceEngine

final class RecurrenceEngineTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func dayNumbers(_ dates: [Date]) -> [Int] {
        dates.map { calendar.component(.day, from: $0) }
    }

    func testWeeklyByWeekday() {
        let november = date(2026, 11, 1, 0) ..< date(2026, 12, 1, 0)
        let rule = RecurrenceRule(frequency: .weekly, byWeekday: [.monday, .wednesday])
        let dates = RecurrenceEngine.occurrences(of: date(2026, 11, 2), rule: rule, in: november, calendar: calendar)
        XCTAssertEqual(dayNumbers(dates), [2, 4, 9, 11, 16, 18, 23, 25, 30])
    }

    func testDailyInterval() {
        let november = date(2026, 11, 1, 0) ..< date(2026, 12, 1, 0)
        let rule = RecurrenceRule(frequency: .daily, interval: 3)
        let dates = RecurrenceEngine.occurrences(of: date(2026, 11, 1), rule: rule, in: november, calendar: calendar)
        XCTAssertEqual(dayNumbers(dates), [1, 4, 7, 10, 13, 16, 19, 22, 25, 28])
    }

    func testCountLimit() {
        let november = date(2026, 11, 1, 0) ..< date(2026, 12, 1, 0)
        let rule = RecurrenceRule(frequency: .weekly, byWeekday: [.friday], count: 3)
        let dates = RecurrenceEngine.occurrences(of: date(2026, 11, 6), rule: rule, in: november, calendar: calendar)
        XCTAssertEqual(dayNumbers(dates), [6, 13, 20])
    }

    func testExcludedDate() {
        let november = date(2026, 11, 1, 0) ..< date(2026, 12, 1, 0)
        let rule = RecurrenceRule(frequency: .daily, excludedDates: [date(2026, 11, 2)])
        let dates = RecurrenceEngine.occurrences(of: date(2026, 11, 1), rule: rule, in: november, calendar: calendar)
        XCTAssertEqual(dates.count, 29)
        XCTAssertFalse(dayNumbers(dates).contains(2))
    }

    func testYearlyHistoricBirthday() {
        let window = date(2024, 1, 1, 0) ..< date(2028, 1, 1, 0)
        let rule = RecurrenceRule(frequency: .yearly)
        let dates = RecurrenceEngine.occurrences(of: date(1985, 6, 15), rule: rule, in: window, calendar: calendar)
        XCTAssertEqual(dates.count, 4)
    }

    func testBiweekly() {
        let november = date(2026, 11, 1, 0) ..< date(2026, 12, 1, 0)
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, byWeekday: [.saturday])
        let dates = RecurrenceEngine.occurrences(of: date(2026, 11, 7), rule: rule, in: november, calendar: calendar)
        XCTAssertEqual(dayNumbers(dates), [7, 21])
    }
}
