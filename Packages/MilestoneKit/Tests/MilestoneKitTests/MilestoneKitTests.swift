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

    private func anniversary(
        calendarType: AnniversaryCalendar,
        solarDate: DateComponents? = nil,
        lunarDate: LunarDateSpec? = nil,
        kind: AnniversaryKind = .birthday,
        fallback: LeapMonthFallback = .previousCommonMonth
    ) -> Anniversary {
        Anniversary(
            title: "测试",
            personName: "张三",
            kind: kind,
            calendar: calendarType,
            solarDate: solarDate,
            lunarDate: lunarDate,
            leapMonthFallback: fallback
        )
    }

    func testSolarBirthdayResolvesSameOrNextYearWithAge() {
        let birthday = anniversary(
            calendarType: .solar,
            solarDate: DateComponents(year: 1998, month: 11, day: 10)
        )
        let occurrence = AnniversaryResolver.nextOccurrence(
            for: birthday,
            onOrAfter: date(2026, 11, 4),
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, date(2026, 11, 10))
        XCTAssertEqual(occurrence?.countText, "28 岁")
        XCTAssertFalse(occurrence?.isFallback ?? true)
    }

    func testLunarLeapMonthExistsWhenPresent() {
        let birthday = anniversary(
            calendarType: .lunar,
            lunarDate: LunarDateSpec(originalYear: 1995, month: 6, day: 1, isLeapMonth: true)
        )
        let occurrence = AnniversaryResolver.nextOccurrence(
            for: birthday,
            onOrAfter: date(2025, 1, 1),
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, date(2025, 8, 23))
        XCTAssertTrue(occurrence?.anniversary.lunarDate?.isLeapMonth ?? false)
        XCTAssertEqual(occurrence?.countText, "30 岁")
        XCTAssertFalse(occurrence?.isFallback ?? true)
    }

    func testMissingLeapMonthUsesPreviousCommonMonthFallback() {
        let birthday = anniversary(
            calendarType: .lunar,
            lunarDate: LunarDateSpec(originalYear: 1995, month: 6, day: 1, isLeapMonth: true)
        )
        let occurrence = AnniversaryResolver.nextOccurrence(
            for: birthday,
            onOrAfter: date(2026, 1, 1),
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, date(2026, 7, 14))
        XCTAssertTrue(occurrence?.isFallback ?? false)
        XCTAssertEqual(occurrence?.fallbackNote?.contains("普通六月"), true)
    }

    func testMissingLeapMonthUsesNextCommonMonthFallback() {
        let birthday = anniversary(
            calendarType: .lunar,
            lunarDate: LunarDateSpec(originalYear: 1995, month: 6, day: 1, isLeapMonth: true),
            fallback: .nextCommonMonth
        )
        let occurrence = AnniversaryResolver.nextOccurrence(
            for: birthday,
            onOrAfter: date(2026, 1, 1),
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, date(2026, 8, 13))
        XCTAssertTrue(occurrence?.isFallback ?? false)
        XCTAssertEqual(occurrence?.fallbackNote?.contains("七月"), true)
    }

    func testMissingLeapMonthSkipYearWaitsForNextLeapYear() {
        let birthday = anniversary(
            calendarType: .lunar,
            lunarDate: LunarDateSpec(originalYear: 1995, month: 6, day: 1, isLeapMonth: true),
            fallback: .skipYear
        )
        let occurrence = AnniversaryResolver.nextOccurrence(
            for: birthday,
            onOrAfter: date(2026, 1, 1),
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, date(2036, 8, 22))
        XCTAssertFalse(occurrence?.isFallback ?? true)
    }

    func testLunarBirthdayCrossesYearWhenDateHasPassed() {
        let birthday = anniversary(
            calendarType: .lunar,
            lunarDate: LunarDateSpec(originalYear: 1998, month: 9, day: 1)
        )
        let occurrence = AnniversaryResolver.nextOccurrence(
            for: birthday,
            onOrAfter: date(2026, 11, 4),
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, date(2027, 9, 30))
        XCTAssertEqual(occurrence?.countText, "29 岁")
    }

    // MARK: - 日程小组件快照

    private func scheduleItem(
        _ id: String,
        _ year: Int, _ month: Int, _ day: Int,
        startHour: Int, endHour: Int,
        isAllDay: Bool = false
    ) -> ScheduleWidgetEventItem {
        ScheduleWidgetEventItem(
            id: id,
            title: "事件 \(id)",
            startDate: date(year, month, day, hour: startHour),
            endDate: date(year, month, day, hour: endHour),
            isAllDay: isAllDay,
            location: nil,
            calendarTitle: "工作",
            colorRGBA: nil
        )
    }

    func testScheduleSnapshotSortsAllDayFirstAndCapsSix() {
        let day = date(2026, 11, 9)
        let items = [
            scheduleItem("a", 2026, 11, 9, startHour: 14, endHour: 15),
            scheduleItem("allday", 2026, 11, 9, startHour: 0, endHour: 24, isAllDay: true),
            scheduleItem("b", 2026, 11, 9, startHour: 9, endHour: 10),
            scheduleItem("other-day", 2026, 11, 10, startHour: 9, endHour: 10),
            scheduleItem("c", 2026, 11, 9, startHour: 11, endHour: 12),
            scheduleItem("d", 2026, 11, 9, startHour: 16, endHour: 17),
            scheduleItem("e", 2026, 11, 9, startHour: 18, endHour: 19),
            scheduleItem("f", 2026, 11, 9, startHour: 20, endHour: 21),
            ScheduleWidgetEventItem(
                id: "overnight",
                title: "跨午夜",
                startDate: date(2026, 11, 8, hour: 22),
                endDate: date(2026, 11, 9, hour: 2),
                isAllDay: false,
                location: nil,
                calendarTitle: "工作",
                colorRGBA: nil
            )
        ]

        let snapshot = ScheduleWidgetSnapshotBuilder.make(
            items: items,
            for: day,
            generatedAt: date(2026, 11, 9, hour: 8),
            calendar: calendar
        )

        XCTAssertEqual(calendar.startOfDay(for: snapshot.day), day)
        XCTAssertEqual(snapshot.events.count, ScheduleWidgetSnapshot.maximumCount)
        XCTAssertEqual(snapshot.events.first?.id, "allday", "全天事件应置顶")
        XCTAssertEqual(
            snapshot.events.dropFirst().map(\.id),
            ["overnight", "b", "c", "a", "d"],
            "时刻事件按开始时间升序，第 7 条起截断"
        )
        XCTAssertFalse(snapshot.events.contains { $0.id == "other-day" })
        XCTAssertTrue(snapshot.events.contains { $0.id == "overnight" }, "跨日重叠事件应包含")
    }

    func testScheduleSnapshotExcludesUnrelatedDays() {
        let day = date(2026, 11, 9)
        let items = [
            scheduleItem("before", 2026, 11, 7, startHour: 9, endHour: 10),
            scheduleItem("after", 2026, 11, 12, startHour: 9, endHour: 10)
        ]

        let snapshot = ScheduleWidgetSnapshotBuilder.make(
            items: items,
            for: day,
            generatedAt: date(2026, 11, 9, hour: 8),
            calendar: calendar
        )

        XCTAssertTrue(snapshot.events.isEmpty)
    }

    // MARK: - 联系人生日导入

    func testContactBirthdayMapperProducesAnniversary() {
        let candidate = ContactBirthdayCandidate(
            contactID: "c-1",
            displayName: "张三",
            month: 5,
            day: 20,
            year: 1990
        )
        let anniversary = ContactBirthdayMapper.anniversary(for: candidate)

        XCTAssertNotNil(anniversary)
        XCTAssertEqual(anniversary?.title, "张三的生日")
        XCTAssertEqual(anniversary?.kind, .birthday)
        XCTAssertEqual(anniversary?.calendar, .solar)
        XCTAssertEqual(anniversary?.solarDate?.year, 1990)
        XCTAssertEqual(anniversary?.solarDate?.month, 5)
        XCTAssertEqual(anniversary?.solarDate?.day, 20)
        XCTAssertEqual(anniversary?.notes, "contact:c-1")
        XCTAssertEqual(anniversary?.showAge, true)
    }

    func testContactBirthdayMapperYearlessBirthdayHidesAge() {
        let candidate = ContactBirthdayCandidate(
            contactID: "c-2",
            displayName: "李四",
            month: 11,
            day: 9,
            year: nil
        )
        let anniversary = ContactBirthdayMapper.anniversary(for: candidate)

        XCTAssertEqual(anniversary?.showAge, false)
        XCTAssertNil(anniversary?.solarDate?.year)
    }

    func testContactBirthdayMapperRejectsInvalidDatesAndDuplicates() {
        XCTAssertNil(ContactBirthdayMapper.anniversary(for: ContactBirthdayCandidate(
            contactID: "x", displayName: "王五", month: 13, day: 1, year: nil
        )))
        XCTAssertNil(ContactBirthdayMapper.anniversary(for: ContactBirthdayCandidate(
            contactID: "x", displayName: "王五", month: 2, day: 30, year: nil
        )))

        let imported = ContactBirthdayMapper.anniversary(for: ContactBirthdayCandidate(
            contactID: "dup", displayName: "赵六", month: 3, day: 8, year: 1985
        ))!
        XCTAssertNil(ContactBirthdayMapper.anniversary(
            for: ContactBirthdayCandidate(contactID: "dup", displayName: "赵六", month: 3, day: 8, year: 1985),
            existing: [imported]
        ))
    }
}
