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
          "source": "sample",
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

    func testBundledManifestLoadsMultipleYears() {
        let store = HolidayStore.bundled()
        XCTAssertEqual(store.statuses.map(\.year), [2026, 2027])
        XCTAssertEqual(store.status(for: 2026)?.source, .sample)
        XCTAssertEqual(store.status(for: 2027)?.source, .sample)
        XCTAssertTrue(store.loadErrors.isEmpty)
    }

    func testBundledYearSelection() {
        let store = HolidayStore.bundled(years: 2026...2026)
        XCTAssertEqual(store.statuses.map(\.year), [2026])
        XCTAssertNil(store.status(for: 2027))
    }

    func testCoverageStates() {
        let store = HolidayStore.bundled()
        XCTAssertEqual(store.coverage(for: date(2026, 2, 17)), .covered)
        XCTAssertEqual(store.coverage(for: date(2026, 3, 5)), .noSpecialDay)
        XCTAssertEqual(store.coverage(for: date(2028, 1, 1)), .yearNotLoaded)

        let unknownStore = HolidayStore(holidays: [])
        XCTAssertEqual(unknownStore.coverage(for: date(2026, 2, 17)), .unknown)
    }

    func testNextHolidayCrossesLoadedYearBoundary() {
        let next = HolidayStore.bundled().nextHoliday(after: date(2026, 12, 31))
        XCTAssertEqual(next?.name, "元旦")
        XCTAssertEqual(calendar.component(.year, from: next?.date ?? Date()), 2027)
    }

    func testSameDayCannotBeBothRestAndWork() throws {
        let json = Data("""
        {
          "year": 2027,
          "source": "sample",
          "holidays": [
            { "name": "元旦", "daysOff": ["2027-01-01"], "workdays": ["2027-01-01"] }
          ]
        }
        """.utf8)

        XCTAssertThrowsError(try HolidayStore(json: json)) { error in
            XCTAssertEqual(error as? HolidayDataError, .conflictingDay(year: 2027, day: "2027-01-01"))
        }
    }

    func testDateMustBeNormalizedAndBelongToDeclaredYear() throws {
        let invalidYear = Data("""
        {
          "year": 2027,
          "source": "sample",
          "holidays": [{ "name": "元旦", "daysOff": ["2026-01-01"], "workdays": [] }]
        }
        """.utf8)
        XCTAssertThrowsError(try HolidayStore(json: invalidYear))

        let nonNormalized = Data("""
        {
          "year": 2027,
          "source": "sample",
          "holidays": [{ "name": "元旦", "daysOff": ["2027-1-1"], "workdays": [] }]
        }
        """.utf8)
        XCTAssertThrowsError(try HolidayStore(json: nonNormalized))
    }

    func testManifestSourceMismatchSkipsYearWithoutCrashing() {
        let manifest = HolidayManifest(version: 1, years: [
            HolidayManifestEntry(
                year: 2027,
                file: "holiday-2027.json",
                source: .official,
                sourceName: "test",
                sourceURL: nil,
                issuedAt: nil
            )
        ])
        let year = HolidayYear(
            year: 2027,
            source: .sample,
            note: nil,
            holidays: [HolidayGroup(name: "元旦", daysOff: ["2027-01-01"], workdays: [])]
        )
        let data = try! JSONEncoder().encode(year)

        let store = HolidayStore(manifest: manifest, yearData: [2027: data])
        XCTAssertNil(store.status(for: 2027))
        XCTAssertEqual(store.coverage(for: date(2027, 1, 1)), .yearNotLoaded)
        XCTAssertEqual(store.loadErrors.count, 1)
    }
}
