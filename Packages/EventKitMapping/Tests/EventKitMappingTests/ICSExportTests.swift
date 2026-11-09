import XCTest
@testable import EventKitMapping

final class ICSExportTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10, minute: Int = 30) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testTimedEventUsesUTCAndCRLF() {
        let event = ICSEvent(
            uid: "abc-123",
            title: "团队会议",
            startDate: date(2026, 11, 9, hour: 18, minute: 0),
            endDate: date(2026, 11, 9, hour: 19, minute: 0),
            isAllDay: false,
            location: "会议室 A",
            notes: nil
        )
        let ics = ICSExporter.calendar(event: event, timestamp: date(2026, 11, 8))

        XCTAssertTrue(ics.contains("\r\n"), "RFC 5545 要求 CRLF")
        XCTAssertTrue(ics.contains("VERSION:2.0"))
        XCTAssertTrue(ics.contains("UID:abc-123"))
        XCTAssertTrue(ics.contains("DTSTAMP:20261108T023000Z"), "时间戳应为 UTC：\(ics)")
        // 上海 18:00 = UTC 10:00
        XCTAssertTrue(ics.contains("DTSTART:20261109T100000Z"))
        XCTAssertTrue(ics.contains("DTEND:20261109T110000Z"))
        XCTAssertTrue(ics.contains("SUMMARY:团队会议"))
        XCTAssertTrue(ics.contains("LOCATION:会议室 A"))
        XCTAssertFalse(ics.contains("DESCRIPTION:"))
        XCTAssertTrue(ics.hasSuffix("END:VCALENDAR\r\n"))
    }

    func testAllDayEventUsesDateValue() {
        let event = ICSEvent(
            uid: "d-1",
            title: "假期",
            startDate: date(2026, 11, 9, hour: 0, minute: 0),
            endDate: date(2026, 11, 10, hour: 0, minute: 0),
            isAllDay: true
        )
        let ics = ICSExporter.calendar(
            event: event,
            timestamp: date(2026, 11, 8),
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        XCTAssertTrue(ics.contains("DTSTART;VALUE=DATE:20261109"))
        XCTAssertTrue(ics.contains("DTEND;VALUE=DATE:20261110"))
    }

    func testTextEscaping() {
        let event = ICSEvent(
            uid: "u1",
            title: "评审,第一轮;日程",
            startDate: date(2026, 11, 9),
            endDate: date(2026, 11, 9, hour: 11),
            isAllDay: false,
            notes: "带\n换行的备注"
        )
        let ics = ICSExporter.calendar(event: event, timestamp: date(2026, 11, 8))

        XCTAssertTrue(ics.contains("SUMMARY:评审\\,第一轮\\;日程"))
        XCTAssertTrue(ics.contains("DESCRIPTION:带\\n换行的备注"))
    }

    func testFileNameTitleSanitization() {
        XCTAssertEqual(ICSExporter.fileNameTitle(for: "a/b\\c:d*e?f"), "a-b-c-d-e-f")
        XCTAssertEqual(ICSExporter.fileNameTitle(for: "   "), "日程")
        XCTAssertEqual(
            ICSExporter.fileNameTitle(for: String(repeating: "长", count: 50)).count,
            40,
            "文件名标题最多 40 字"
        )
    }
}
