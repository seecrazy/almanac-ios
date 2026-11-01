import XCTest
@testable import HolidayData

final class HolidayDataTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = LunarCalendarShanghai.timezone
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testBundledSampleRestDay() {
        XCTAssertEqual(HolidayStore.bundled().effect(for: date(2026, 2, 17)), .restDay(name: "春节"))
    }

    func testBundledSampleMakeupWorkday() {
        XCTAssertEqual(HolidayStore.bundled().effect(for: date(2026, 2, 14)), .workday(name: "春节"))
    }

    func testOrdinaryDayHasNoEffect() {
        XCTAssertNil(HolidayStore.bundled().effect(for: date(2026, 3, 5)))
    }

    func testNextHolidaySkipsWorkdayAndUsesRestDay() {
        let next = HolidayStore.bundled().nextHoliday(after: date(2026, 9, 30))
        XCTAssertEqual(next?.name, "国庆")
        XCTAssertEqual(calendar.component(.month, from: next?.date ?? Date()), 10)
    }

    func testJSONDecoding() throws {
        let json = Data("""
        {
          "year": 2027,
          "source": "official",
          "note": "test",
          "holidays": [
            {
              "name": "元旦",
              "daysOff": ["2027-01-01"],
              "workdays": []
            }
          ]
        }
        """.utf8)
        let store = try HolidayStore(json: json)
        XCTAssertEqual(store.effect(for: date(2027, 1, 1)), .restDay(name: "元旦"))
        XCTAssertEqual(store.nextHoliday(after: date(2026, 12, 31))?.name, "元旦")
    }
}
