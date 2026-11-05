import XCTest
@testable import CalendarAnalysis

final class CalendarAnalysisTests: XCTestCase {
    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        date(hour, minute, day: 5)
    }

    private func date(_ hour: Int, _ minute: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = day
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: components)!
    }

    private func event(
        _ id: String,
        _ title: String,
        _ startHour: Int,
        _ endHour: Int,
        startMinute: Int = 0,
        endMinute: Int = 0,
        isAllDay: Bool = false
    ) -> AnalysisEvent {
        AnalysisEvent(
            id: id,
            title: title,
            startDate: date(startHour, startMinute),
            endDate: date(endHour, endMinute),
            isAllDay: isAllDay
        )
    }

    func testInvalidEventsAreIgnoredAndEndpointTouchIsNotConflict() {
        let groups = CalendarConflictAnalyzer.conflictGroups(in: [
            event("invalid", "无效", 10, 10),
            event("a", "A", 10, 11),
            event("b", "B", 11, 12)
        ])
        XCTAssertTrue(groups.isEmpty)
    }

    func testOverlappingEventsFormOneConflictGroup() throws {
        let groups = CalendarConflictAnalyzer.conflictGroups(in: [
            event("a", "A", 10, 11),
            event("b", "B", 10, 12, startMinute: 30)
        ])
        XCTAssertEqual(groups.count, 1)
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(group.events.map(\.id), ["a", "b"])
        XCTAssertEqual(group.interval.start, date(10))
        XCTAssertEqual(group.interval.end, date(12))
    }

    func testChainOfThreeEventsFormsSingleConnectedGroup() throws {
        let groups = CalendarConflictAnalyzer.conflictGroups(in: [
            event("a", "A", 9, 10),
            event("b", "B", 9, 11, startMinute: 30),
            event("c", "C", 10, 12, startMinute: 30)
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.events.map(\.id), ["a", "b", "c"])
    }

    func testAllDayConflictsAndClearsFreeSlots() {
        let allDay = event("all", "休假", 0, 24, isAllDay: true)
        let meeting = event("a", "会议", 10, 11)
        let groups = CalendarConflictAnalyzer.conflictGroups(in: [allDay, meeting])
        XCTAssertEqual(groups.count, 1)

        let slots = CalendarConflictAnalyzer.freeSlots(
            on: date(10),
            events: [allDay, meeting]
        )
        XCTAssertTrue(slots.isEmpty)
    }

    func testFreeSlotsMergeBusyEventsAndRespectMinimumAndMaximum() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let slots = CalendarConflictAnalyzer.freeSlots(
            on: date(10),
            events: [
                event("a", "A", 9, 10),
                event("b", "B", 9, 11, startMinute: 30),
                event("cross", "跨天", 7, 13),
                event("c", "C", 13, 14)
            ],
            calendar: calendar,
            minimumDuration: 30 * 60,
            maximumCount: 2
        )

        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots.first?.startDate, date(0))
        XCTAssertEqual(slots.first?.endDate, date(7))
        XCTAssertEqual(slots.last?.startDate, date(14))
        XCTAssertEqual(slots.last?.endDate, date(24))
    }

    func testConflictGroupsClipToWindowAndCapTwenty() {
        var events = [
            event("long", "长日程", 8, 12),
            AnalysisEvent(
                id: "edge",
                title: "边界",
                startDate: date(10, 30),
                endDate: date(11, 30)
            )
        ]

        for day in 6...7 {
            for index in 0..<10 {
                let startHour = index * 2 + 1
                events.append(
                    AnalysisEvent(
                        id: "\(day)-a-\(index)",
                        title: "A",
                        startDate: date(startHour, 0, day: day),
                        endDate: date(startHour + 1, 0, day: day)
                    )
                )
                events.append(
                    AnalysisEvent(
                        id: "\(day)-b-\(index)",
                        title: "B",
                        startDate: date(startHour, 30, day: day),
                        endDate: date(startHour + 1, 30, day: day)
                    )
                )
            }
        }

        let window = DateInterval(start: date(9), end: date(13))
        let clippedGroups = CalendarConflictAnalyzer.conflictGroups(
            in: [events[0], events[1]],
            within: window
        )
        XCTAssertEqual(clippedGroups.count, 1)
        XCTAssertEqual(clippedGroups.first?.interval.start, date(9))
        XCTAssertEqual(clippedGroups.first?.interval.end, date(12))

        XCTAssertEqual(
            CalendarConflictAnalyzer.conflictGroups(in: events).count,
            CalendarConflictAnalyzer.maximumConflictGroups
        )
    }

    func testMinimumFreeDurationIsClampedToOneMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let slots = CalendarConflictAnalyzer.freeSlots(
            on: date(10),
            events: [event("busy", "忙碌", 10, 11)],
            calendar: calendar,
            minimumDuration: 0,
            maximumCount: 6
        )

        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots.first?.endDate, date(10))
        XCTAssertEqual(slots.last?.startDate, date(11))
        XCTAssertTrue(slots.allSatisfy { $0.duration >= 60 })
    }
}
