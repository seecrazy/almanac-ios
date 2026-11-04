import XCTest
@testable import NaturalInput

final class NaturalInputParserTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.firstWeekday = 2
        return calendar
    }()

    private var reference: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testRelativeDateAndTimeRange() {
        let result = parser.parse("明天下午3点到5点 开会 @会议室 #重要", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.title, "开会")
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 3, 15))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 3, 17))
        XCTAssertEqual(result.draft.location, "会议室")
        XCTAssertEqual(result.draft.notes, "重要")
        XCTAssertEqual(result.draft.recurrence.mode, .none)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testExplicitChineseDateWithClockTimeAndHalfHour() {
        let result = parser.parse("11月8日上午9点半 体检", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 8, 9, 30))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 8, 10, 30))
        XCTAssertEqual(result.draft.title, "体检")
    }

    func testExplicitISOAndSlashDates() {
        let iso = parser.parse("2026-11-12 08:15 提交材料", reference: reference, calendar: calendar)
        XCTAssertEqual(iso.draft.startDate, date(2026, 11, 12, 8, 15))
        XCTAssertEqual(iso.draft.title, "提交材料")

        let slash = parser.parse("12/20 全天 盘点", reference: reference, calendar: calendar)
        XCTAssertTrue(slash.draft.isAllDay)
        XCTAssertEqual(slash.draft.startDate, date(2026, 12, 20))
        XCTAssertEqual(slash.draft.endDate, date(2026, 12, 21))
        XCTAssertEqual(slash.draft.title, "盘点")
    }

    func testTwentyFourHourRangeAndDuration() {
        let result = parser.parse("11月10日 19:00-20:30 复习 2小时", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 10, 19))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 10, 20, 30))
        XCTAssertTrue(result.draft.title.contains("2小时"))
    }

    func testDurationAfterSingleTime() {
        let result = parser.parse("明天15点 运动 45分钟", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 3, 15))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 3, 15, 45))
        XCTAssertEqual(result.draft.title, "运动")
    }

    func testAllDay() {
        let result = parser.parse("11月11日全天 旅行", reference: reference, calendar: calendar)
        XCTAssertTrue(result.draft.isAllDay)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 11))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 12))
    }

    func testWeeklyRecurrenceFindsNextWeekday() {
        let result = parser.parse("每周三18:00 运动", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.recurrence.mode, .weekly)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 4, 18))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 4, 19))
    }

    func testWeeklyRecurrenceDoesNotTreatOrdinaryDayTextAsWeekday() {
        let result = parser.parse("每周 写日报", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.recurrence.mode, .weekly)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 2, 9))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 2, 10))
        XCTAssertEqual(result.draft.title, "写日报")
    }

    func testNextWeekdayUsesNextNaturalWeek() {
        let result = parser.parse("下周三 14:00 复诊", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 11, 14))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 11, 15))
    }

    func testMissingDateAndTimeUsesReferenceWithWarnings() {
        let result = parser.parse("写周报", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 2, 9))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 2, 10))
        XCTAssertEqual(result.draft.title, "写周报")
        XCTAssertEqual(result.warnings, ["未识别日期，已按今天处理", "未识别时间，已按 09:00–10:00 处理"])
    }

    func testMissingTitleProducesWarning() {
        let result = parser.parse("明天下午3点到5点", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.title, "新日程")
        XCTAssertTrue(result.warnings.contains("未识别标题，请补充标题"))
    }

    func testCrossMidnightRange() {
        let result = parser.parse("明天22:00-1:00 值班", reference: reference, calendar: calendar)
        XCTAssertEqual(result.draft.startDate, date(2026, 11, 3, 22))
        XCTAssertEqual(result.draft.endDate, date(2026, 11, 4, 1))
        XCTAssertTrue(result.warnings.contains("结束时间早于开始时间，已按跨天处理"))
    }

    func testRecurrenceModes() {
        let cases: [(String, NaturalRecurrenceMode)] = [
            ("每天 散步", .daily),
            ("每两周 复查", .biweekly),
            ("每月 交房租", .monthly),
            ("每年 体检", .yearly)
        ]
        for (input, expected) in cases {
            XCTAssertEqual(parser.parse(input, reference: reference, calendar: calendar).draft.recurrence.mode, expected)
        }
    }

    private var parser: NaturalInputParser { NaturalInputParser(rules: .fallback) }
}
