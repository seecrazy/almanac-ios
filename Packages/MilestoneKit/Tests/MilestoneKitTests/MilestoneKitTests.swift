import XCTest
@testable import MilestoneKit

final class MilestoneKitTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func item(
        id: UUID = UUID(),
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0
    ) -> MilestoneSnapshotItem {
        MilestoneSnapshotItem(
            id: id,
            title: "里程碑",
            targetDate: date(year, month, day, hour: hour),
            isAllDay: hour == 0,
            category: "custom"
        )
    }

    func testSnapshotPrioritizesSevenDayWindowAndCapsEight() {
        let now = date(2026, 11, 4, hour: 10)
        let items = [
            item(2026, 11, 20),
            item(2026, 11, 5),
            item(2026, 11, 4, hour: 11),
            item(2026, 11, 10),
            item(2026, 12, 1),
            item(2026, 11, 4, hour: 9),
            item(2026, 11, 6),
            item(2026, 11, 7),
            item(2026, 11, 8),
            item(2026, 11, 3)
        ]
        let snapshot = MilestoneSnapshotBuilder.make(
            milestones: items,
            generatedAt: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.version, 1)
        XCTAssertEqual(snapshot.milestones.count, 8)
        XCTAssertFalse(snapshot.milestones.contains { $0.targetDate < now && !$0.isAllDay })
        XCTAssertEqual(snapshot.milestones.first?.targetDate, date(2026, 11, 4, hour: 11))
        XCTAssertTrue(snapshot.milestones.allSatisfy { $0.targetDate >= now })
    }

    func testDisabledAndPastRemindersAreOmitted() {
        let now = date(2026, 11, 4, hour: 10)
        let requests = MilestoneNotificationPlanner.requests(
            milestoneID: UUID(),
            title: "高考",
            targetDate: date(2026, 11, 12, hour: 9),
            isAllDay: false,
            reminders: [
                MilestoneReminder(kind: .sevenDaysAtNine, isEnabled: false),
                MilestoneReminder(kind: .oneDayAtNine),
                MilestoneReminder(kind: .sameDayAtNine),
                MilestoneReminder(kind: .sameDayAtTarget),
            ],
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests.map(\.fireDate), [
            date(2026, 11, 11, hour: 9),
            date(2026, 11, 12, hour: 9),
            date(2026, 11, 12, hour: 9)
        ])
    }

    func testAllDayReminderTimesAndBodies() {
        let now = date(2026, 11, 1, hour: 8)
        let id = UUID()
        let requests = MilestoneNotificationPlanner.requests(
            milestoneID: id,
            title: "高考",
            targetDate: date(2026, 11, 10),
            isAllDay: true,
            reminders: MilestoneReminderKind.allCases.map {
                MilestoneReminder(kind: $0)
            },
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(requests.count, 4)
        XCTAssertEqual(requests.map(\.fireDate), [
            date(2026, 11, 3, hour: 9),
            date(2026, 11, 9, hour: 9),
            date(2026, 11, 10, hour: 9),
            date(2026, 11, 10)
        ])
        XCTAssertEqual(requests.first?.body, "距离「高考」还有 7 天")
        XCTAssertEqual(requests.first?.identifier, "milestone.\(id.uuidString).sevenDaysAtNine")
    }

    func testSixtyDayLimitAndIdentifierPrefix() {
        let now = date(2026, 11, 4, hour: 10)
        let id = UUID()
        let requests = MilestoneNotificationPlanner.requests(
            milestoneID: id,
            title: "远期项目",
            targetDate: date(2027, 3, 1, hour: 9),
            isAllDay: false,
            reminders: [MilestoneReminder(kind: .sevenDaysAtNine)],
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(
            MilestoneNotificationPlanner.identifierPrefix(milestoneID: id),
            "milestone.\(id.uuidString)."
        )
    }
}
