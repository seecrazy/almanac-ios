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
        XCTAssertEqual(LunarCalendar.displayText(for: LunarDate(year: 2023, month: 2, day: 3, isLeapMonth: true)), "初三")
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

    // MARK: 二十四节气

    func testSolarTermCatalogCompletenessAndOrder() throws {
        XCTAssertEqual(SolarTermName.allCases.count, 24)
        XCTAssertEqual(Set(SolarTermName.allCases.map(\.rawValue)).count, 24)

        let terms = try XCTUnwrap(SolarTermCalendar.terms(inGregorianYear: 2026))
        XCTAssertEqual(terms.count, 24)
        XCTAssertEqual(terms.map(\.name), SolarTermName.allCases)
        XCTAssertTrue(zip(terms, terms.dropFirst()).allSatisfy { $0.date < $1.date })
        XCTAssertTrue(
            terms.first!.date < terms.last!.date
        )
    }

    func testSolarTermAnchorsUseShanghaiDay() throws {
        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = LunarCalendar.timeZone
        func isSameShanghaiDay(_ left: Date, _ right: Date) -> Bool {
            shanghaiCalendar.isDate(left, inSameDayAs: right)
        }

        let supportedYears = [1900, 1949, 2024, 2026]
        for year in supportedYears {
            XCTAssertNotNil(SolarTermCalendar.terms(inGregorianYear: year))
        }

        let historicalAnchors: [(year: Int, SolarTermName, (month: Int, day: Int))] = [
            (1900, .springBegins, (2, 4)),
            (1900, .springEquinox, (3, 21)),
            (1900, .summerSolstice, (6, 22)),
            (1900, .winterSolstice, (12, 22)),
            (1949, .springBegins, (2, 4)),
            (1949, .springEquinox, (3, 21)),
            (1949, .summerSolstice, (6, 22)),
            (1949, .winterSolstice, (12, 22))
        ]
        for (year, name, anchor) in historicalAnchors {
            let term = try XCTUnwrap(
                SolarTermCalendar.terms(inGregorianYear: year)?.first { $0.name == name }
            )
            XCTAssertTrue(
                isSameShanghaiDay(term.date, date(year, anchor.month, anchor.day)),
                "\(year) \(name.rawValue) 应落在 \(anchor)"
            )
        }

        let anchors: [(SolarTermName, (year: Int, month: Int, day: Int))] = [
            (.springBegins, (2026, 2, 4)),
            (.springEquinox, (2026, 3, 20)),
            (.summerSolstice, (2026, 6, 21)),
            (.winterSolstice, (2026, 12, 22))
        ]

        for (name, anchor) in anchors {
            let term = try XCTUnwrap(
                SolarTermCalendar.terms(inGregorianYear: 2026)?.first { $0.name == name }
            )
            XCTAssertTrue(
                isSameShanghaiDay(term.date, date(anchor.year, anchor.month, anchor.day)),
                "\(name.rawValue) 应落在 \(anchor)"
            )
        }

        let anchors2024: [(SolarTermName, (year: Int, month: Int, day: Int))] = [
            (.springBegins, (2024, 2, 4)),
            (.springEquinox, (2024, 3, 20)),
            (.summerSolstice, (2024, 6, 21)),
            (.winterSolstice, (2024, 12, 21))
        ]
        for (name, anchor) in anchors2024 {
            let term = try XCTUnwrap(
                SolarTermCalendar.terms(inGregorianYear: 2024)?.first { $0.name == name }
            )
            XCTAssertTrue(
                isSameShanghaiDay(term.date, date(anchor.year, anchor.month, anchor.day)),
                "\(name.rawValue) 应落在 \(anchor)"
            )
        }
    }

    func testSolarTermDayLookupAndOutsideSupport() {
        XCTAssertEqual(SolarTermCalendar.term(on: date(2026, 2, 4))?.name, .springBegins)
        XCTAssertEqual(SolarTermCalendar.displayName(for: date(2026, 2, 4)), "立春")
        XCTAssertNil(SolarTermCalendar.term(on: date(2026, 2, 5)))
        XCTAssertNil(SolarTermCalendar.terms(inGregorianYear: 1899))
        XCTAssertNil(SolarTermCalendar.terms(inGregorianYear: 2101))
    }

    // MARK: 农历节日

    func testLunarFestivalCatalogCompletenessAndOrder() {
        XCTAssertEqual(LunarFestivalName.allCases.count, 10)
        XCTAssertEqual(Set(LunarFestivalName.allCases.map(\.rawValue)).count, 10)

        for year in LunarFestivalCalendar.firstLunarYear...(LunarFestivalCalendar.lastLunarYear - 1) {
            let festivals = LunarFestivalCalendar.festivals(inLunarYear: year)
            XCTAssertEqual(festivals?.count, 10, "\(year) 应有 10 个节日")
            XCTAssertTrue(
                zip(festivals ?? [], (festivals ?? []).dropFirst()).allSatisfy {
                    $0.date < $1.date
                }
            )
        }

        // 2101 年春节超出农历数据表，因此 2100 农历年的除夕不能推导。
        XCTAssertEqual(
            LunarFestivalCalendar.festivals(inLunarYear: LunarFestivalCalendar.lastLunarYear)?.count,
            9
        )
        XCTAssertNil(LunarFestivalCalendar.festivals(inLunarYear: 1899))
        XCTAssertNil(LunarFestivalCalendar.festivals(inLunarYear: 2101))
    }

    func testLunarFestivalAnchors() {
        let anchors: [(LunarFestivalName, (year: Int, month: Int, day: Int))] = [
            (.springFestival, (2026, 2, 17)),
            (.lanternFestival, (2026, 3, 3)),
            (.midAutumnFestival, (2026, 9, 25)),
            (.midAutumnFestival, (2024, 9, 17)),
            (.newYearsEve, (2027, 2, 5)),
            (.newYearsEve, (2025, 1, 28))
        ]

        for (name, anchor) in anchors {
            let festival = LunarFestivalCalendar.festival(
                on: date(anchor.year, anchor.month, anchor.day)
            )
            XCTAssertEqual(festival?.name, name, "\(name.rawValue) 锚点错误")
        }

        XCTAssertNil(LunarFestivalCalendar.festival(on: date(2026, 2, 18)))
        XCTAssertNil(LunarFestivalCalendar.festival(on: date(1899, 12, 31)))
    }

    // MARK: 黄历

    func testBundledAlmanacRulesDecodeTwentyFourActivities() throws {
        let rules = try XCTUnwrap(AlmanacRuleSet.bundled())
        XCTAssertEqual(rules.version, 1)
        XCTAssertEqual(rules.duties.count, 12)
        XCTAssertEqual(rules.clash.count, 12)
        XCTAssertEqual(rules.activities.count, 24)
        XCTAssertEqual(Set(rules.duties).count, 12)
        XCTAssertEqual(Set(rules.clash.map(\.dayBranch)).count, 12)
        XCTAssertEqual(Set(rules.activities.map(\.id)).count, 24)
        XCTAssertTrue(rules.activities.allSatisfy {
            Set($0.suitableDuties).isDisjoint(with: $0.avoidDuties)
        })
    }

    func testAlmanacMonthYearAndRuleFiltering() throws {
        let rules = try XCTUnwrap(AlmanacRuleSet.bundled())
        let springFestival = AlmanacCalendar.day(for: date(2026, 2, 17), rules: rules)

        XCTAssertEqual(springFestival.yearGanZhi, "丙午")
        XCTAssertEqual(springFestival.monthGanZhi, "庚寅")
        XCTAssertEqual(springFestival.zodiac, "马")
        XCTAssertEqual(springFestival.dayGanZhi, GanZhi.dayGanZhi(for: date(2026, 2, 17)))
        XCTAssertEqual(springFestival.source, .rule)
        XCTAssertFalse(springFestival.suitable.isEmpty)
        XCTAssertFalse(springFestival.avoid.isEmpty)
        XCTAssertTrue(
            Set(springFestival.suitable.map(\.id))
                .isDisjoint(with: Set(springFestival.avoid.map(\.id)))
        )
    }

    func testAlmanacClashUsesDayBranchRule() throws {
        let rules = try XCTUnwrap(AlmanacRuleSet.bundled())
        let anchor = AlmanacCalendar.day(for: date(1949, 10, 1), rules: rules)

        XCTAssertEqual(anchor.dayGanZhi, "甲子")
        XCTAssertEqual(anchor.clash?.conflictBranch, "午")
        XCTAssertEqual(anchor.clash?.direction, "南")
    }

    func testAlmanacDateOutsideLunarSupportIsExplicit() throws {
        let rules = try XCTUnwrap(AlmanacRuleSet.bundled())
        XCTAssertNil(AlmanacCalendar.day(for: date(1899, 12, 31), rules: rules).lunar)
        XCTAssertNil(AlmanacCalendar.day(for: date(2102, 3, 1), rules: rules).lunar)
        XCTAssertEqual(
            AlmanacCalendar.day(for: date(2102, 3, 1), rules: rules).yearGanZhi,
            "壬戌"
        )
    }

    func testCorruptAlmanacRulesStillProduceCoreFields() throws {
        let data = Data("not-json".utf8)
        XCTAssertThrowsError(try AlmanacRuleSet.decode(from: data))
        let day = AlmanacCalendar.day(for: date(2026, 2, 17), rules: nil)

        XCTAssertEqual(day.yearGanZhi, "丙午")
        XCTAssertTrue(day.suitable.isEmpty)
        XCTAssertTrue(day.avoid.isEmpty)
    }
}
