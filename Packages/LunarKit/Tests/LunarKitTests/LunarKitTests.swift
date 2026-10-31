import XCTest
@testable import LunarKit

final class LunarKitTests: XCTestCase {

    /// 在 Asia/Shanghai 时区构造公历日期
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = LunarCalendar.timeZone
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return c.date(from: comps)!
    }

    // MARK: 公历 → 农历（春节锚点）

    func testSpringFestival2026() {
        let lunar = LunarCalendar.lunar(from: date(2026, 2, 17))
        XCTAssertEqual(lunar, LunarDate(year: 2026, month: 1, day: 1))
    }

    func testSpringFestival2025() {
        let lunar = LunarCalendar.lunar(from: date(2025, 1, 29))
        XCTAssertEqual(lunar, LunarDate(year: 2025, month: 1, day: 1))
    }

    func testSpringFestival2024() {
        let lunar = LunarCalendar.lunar(from: date(2024, 2, 10))
        XCTAssertEqual(lunar, LunarDate(year: 2024, month: 1, day: 1))
    }

    func testMidAutumn2024() {
        let lunar = LunarCalendar.lunar(from: date(2024, 9, 17))
        XCTAssertEqual(lunar, LunarDate(year: 2024, month: 8, day: 15))
    }

    // MARK: 闰月

    func testLeapMonthLookup() {
        XCTAssertEqual(LunarCalendar.leapMonth(of: 2023), 2, "2023 年闰二月")
        XCTAssertEqual(LunarCalendar.leapMonth(of: 2025), 6, "2025 年闰六月")
        XCTAssertEqual(LunarCalendar.leapMonth(of: 2026), 0, "2026 年无闰月")
    }

    // MARK: 农历 → 公历（往返一致性）

    func testRoundTrip() {
        let samples = [date(2026, 2, 17), date(2024, 9, 17), date(2025, 8, 15), date(2026, 10, 31)]
        for d in samples {
            let lunar = LunarCalendar.lunar(from: d)
            let back = LunarCalendar.solar(from: lunar)
            var c = Calendar(identifier: .gregorian)
            c.timeZone = LunarCalendar.timeZone
            XCTAssertEqual(c.startOfDay(for: back!), c.startOfDay(for: d), "往返失败: \(d)")
        }
    }

    // MARK: 文本

    func testDisplayText() {
        XCTAssertEqual(LunarCalendar.displayText(for: LunarDate(year: 2026, month: 1, day: 1)), "正月")
        XCTAssertEqual(LunarCalendar.displayText(for: LunarDate(year: 2024, month: 8, day: 15)), "十五")
        XCTAssertEqual(LunarCalendar.displayText(for: LunarDate(year: 2023, month: 2, day: 3, isLeapMonth: true)), "闰二月")
    }

    // MARK: 干支

    func testDayGanZhiAnchor() {
        // 1949-10-01 为甲子日
        XCTAssertEqual(GanZhi.dayGanZhi(for: date(1949, 10, 1)), "甲子")
        XCTAssertEqual(GanZhi.dayGanZhiIndex(for: date(1949, 10, 1)), 0)
    }

    func testYearGanZhi() {
        XCTAssertEqual(GanZhi.yearGanZhi(forGregorianYear: 2026).ganZhi, "丙午")
        XCTAssertEqual(GanZhi.yearGanZhi(forGregorianYear: 2026).zodiac, "马")
        XCTAssertEqual(GanZhi.yearGanZhi(forGregorianYear: 2024).ganZhi, "甲辰")
    }
}
