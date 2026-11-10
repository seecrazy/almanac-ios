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

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testBundledOfficialRestDay() {
        XCTAssertEqual(HolidayStore.bundled().effect(for: date(2026, 2, 17)), .restDay(name: "春节"))
    }

    func testBundledOfficialMakeupWorkday() {
        XCTAssertEqual(HolidayStore.bundled().effect(for: date(2026, 2, 14)), .workday(name: "春节"))
    }

    func testBundledOfficial2026Schedule() {
        let store = HolidayStore.bundled()
        XCTAssertEqual(store.effect(for: date(2026, 1, 4)), .workday(name: "元旦"))
        XCTAssertEqual(store.effect(for: date(2026, 2, 23)), .restDay(name: "春节"))
        XCTAssertEqual(store.effect(for: date(2026, 2, 28)), .workday(name: "春节"))
        XCTAssertEqual(store.effect(for: date(2026, 5, 9)), .workday(name: "劳动节"))
        XCTAssertEqual(store.effect(for: date(2026, 6, 20)), .restDay(name: "端午节"))
        XCTAssertEqual(store.effect(for: date(2026, 9, 20)), .workday(name: "国庆节"))
        XCTAssertEqual(store.effect(for: date(2026, 9, 26)), .restDay(name: "中秋节"))
    }

    func testOrdinaryDayHasNoEffect() {
        XCTAssertNil(HolidayStore.bundled().effect(for: date(2026, 3, 5)))
    }

    func testNextHolidaySkipsWorkdayAndUsesRestDay() {
        let next = HolidayStore.bundled().nextHoliday(after: date(2026, 9, 30))
        XCTAssertEqual(next?.name, "国庆节")
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
        XCTAssertEqual(store.status(for: 2026)?.source, .official)
        XCTAssertEqual(store.status(for: 2026)?.sourceName, "国务院办公厅通知")
        // 2027 已随官方通知替换为 official（ADR-013）。
        XCTAssertEqual(store.status(for: 2027)?.source, .official)
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
    }

    func testWorkdayTemplateAndOfficialAdjustmentsOverrideBaseWeekdays() {
        let store = HolidayStore.bundled()
        let standard = WorkdayResolver.planDay(
            date(2026, 3, 7),
            template: WorkdayTemplate(kind: .standardFiveDay),
            holidays: store
        )

        XCTAssertFalse(standard.baseIsWorkday)
        XCTAssertFalse(standard.shouldRing)
        XCTAssertEqual(standard.reason, "周六，闹钟关闭")
        XCTAssertEqual(standard.holidayCoverage, .noSpecialDay)

        let sixDay = WorkdayResolver.planDay(
            date(2026, 3, 7),
            template: WorkdayTemplate(kind: .sixDayWeek),
            holidays: store
        )
        XCTAssertTrue(sixDay.shouldRing)
        XCTAssertEqual(sixDay.reason, "周六，闹钟开启")

        let custom = WorkdayResolver.planDay(
            date(2026, 3, 8),
            template: WorkdayTemplate(kind: .custom, customWeekdays: [1, 3]),
            holidays: store
        )
        XCTAssertTrue(custom.shouldRing)
        XCTAssertEqual(custom.reason, "周日，闹钟开启")

        let singleRest = WorkdayResolver.planDay(
            date(2026, 3, 8),
            template: .singleRest,
            holidays: store
        )
        XCTAssertFalse(singleRest.baseIsWorkday)
        XCTAssertFalse(singleRest.shouldRing)
        XCTAssertEqual(singleRest.reason, "周日，闹钟关闭")

        let officialRest = WorkdayResolver.planDay(
            date(2026, 2, 17),
            template: WorkdayTemplate(kind: .standardFiveDay),
            holidays: store
        )
        XCTAssertEqual(officialRest.holidayAdjustment, .restDay(name: "春节"))
        XCTAssertFalse(officialRest.shouldRing)
        XCTAssertEqual(officialRest.reason, "法定休息日，闹钟关闭")

        let officialWork = WorkdayResolver.planDay(
            date(2026, 2, 14),
            template: WorkdayTemplate(kind: .standardFiveDay),
            holidays: store
        )
        XCTAssertEqual(officialWork.holidayAdjustment, .workday(name: "春节"))
        XCTAssertTrue(officialWork.shouldRing)
        XCTAssertEqual(officialWork.reason, "调休补班日，闹钟开启")
    }

    func testWorkdayPlanLimitsSixtyDaysAndMarksUnknownCoverage() {
        let plans = WorkdayResolver.plan(
            from: date(2026, 3, 5),
            days: 100,
            template: WorkdayTemplate(kind: .standardFiveDay),
            holidays: HolidayStore.bundled()
        )

        XCTAssertEqual(plans.count, 60)
        XCTAssertEqual(
            plans.map(\.date),
            plans.map { plan in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = LunarCalendarShanghai.timezone
                return calendar.startOfDay(for: plan.date)
            }
        )

        let unknownPlan = WorkdayResolver.planDay(
            date(2028, 1, 1),
            template: WorkdayTemplate(kind: .standardFiveDay),
            holidays: HolidayStore.bundled()
        )
        XCTAssertEqual(unknownPlan.holidayCoverage, .yearNotLoaded)
        XCTAssertEqual(unknownPlan.reason, "节假日数据未覆盖，按模板执行")

        let legacyUnknown = WorkdayResolver.planDay(
            date(2026, 3, 5),
            template: WorkdayTemplate(kind: .standardFiveDay),
            holidays: HolidayStore(holidays: [])
        )
        XCTAssertEqual(legacyUnknown.holidayCoverage, .unknown)
        XCTAssertEqual(legacyUnknown.reason, "节假日数据未覆盖，按模板执行")
    }

    func testWorkdayAlarmPlannerRespectsHolidayMakeupAndMultipleAlarms() {
        let store = HolidayStore.bundled()
        let reference = date(2026, 2, 14, hour: 6)
        let early = WorkdayAlarm(name: "早班", time: date(2026, 2, 14, hour: 7, minute: 30))
        let late = WorkdayAlarm(name: "晚班", time: date(2026, 2, 14, hour: 8, minute: 45))
        let disabled = WorkdayAlarm(name: "休息", time: date(2026, 2, 14, hour: 9), isEnabled: false)

        let occurrences = WorkdayAlarmPlanner.occurrences(
            alarms: [early, late, disabled],
            template: .standard,
            holidays: store,
            from: reference,
            calendar: calendar
        )

        let makeupOccurrences = occurrences.filter {
            calendar.isDate($0.plan.date, inSameDayAs: date(2026, 2, 14))
        }
        XCTAssertEqual(makeupOccurrences.count, 2)
        XCTAssertEqual(makeupOccurrences.map(\.alarm.name), ["早班", "晚班"])
        XCTAssertTrue(makeupOccurrences.allSatisfy { $0.plan.holidayAdjustment == .workday(name: "春节") })
        XCTAssertEqual(calendar.dateComponents([.hour, .minute], from: occurrences[0].fireDate), DateComponents(hour: 7, minute: 30))
        XCTAssertEqual(calendar.dateComponents([.hour, .minute], from: occurrences[1].fireDate), DateComponents(hour: 8, minute: 45))
    }

    func testWorkdayAlarmPlannerSkipsOfficialRestDaysAndCapsAlarmCount() {
        let store = HolidayStore.bundled()
        let reference = date(2026, 2, 15, hour: 6)
        let alarms = (0..<WorkdayAlarmPlanner.maximumAlarmCount + 1).map { index in
            WorkdayAlarm(
                name: "闹钟 \(index)",
                time: date(2026, 2, 15, hour: 8, minute: index)
            )
        }

        let occurrences = WorkdayAlarmPlanner.occurrences(
            alarms: alarms,
            template: .standard,
            holidays: store,
            from: reference,
            calendar: calendar
        )

        XCTAssertEqual(Set(occurrences.map(\.alarm.id)).count, WorkdayAlarmPlanner.maximumAlarmCount)
        XCTAssertFalse(occurrences.contains {
            calendar.isDate($0.plan.date, inSameDayAs: date(2026, 2, 16))
        })
        XCTAssertEqual(
            occurrences.first.map { calendar.isDate($0.plan.date, inSameDayAs: date(2026, 2, 24)) },
            true
        )
        XCTAssertTrue(occurrences.allSatisfy { !$0.plan.shouldRing || $0.fireDate > reference })
    }

    // MARK: - NotificationBudgetPlanner

    func testNotificationBudgetTrimmingKeepsEarliestRequests() {
        let occurrences = WorkdayAlarmPlanner.occurrences(
            alarms: [WorkdayAlarm(name: "闹钟", time: date(2026, 2, 16, hour: 7, minute: 30))],
            template: .standard,
            holidays: HolidayStore.bundled(),
            from: date(2026, 2, 15, hour: 6),
            calendar: calendar
        )
        XCTAssertGreaterThan(occurrences.count, 3, "60 天窗口内应有多条计划")

        let trimmed = NotificationBudgetPlanner.trimming(occurrences, budget: 3)
        XCTAssertEqual(trimmed.count, 3)
        XCTAssertEqual(trimmed, Array(occurrences.prefix(3)), "应保留最早触发的请求")
    }

    func testNotificationBudgetTrimmingBoundaries() {
        XCTAssertTrue(NotificationBudgetPlanner.trimming([1, 2, 3], budget: 0).isEmpty)
        XCTAssertTrue(NotificationBudgetPlanner.trimming([1, 2, 3], budget: -5).isEmpty)
        XCTAssertEqual(NotificationBudgetPlanner.trimming([1, 2], budget: 10), [1, 2])
    }

    // MARK: - 远程数据集

    private func remoteDatasetJSON(year: Int, days: [[String: Any]], papers: [String]? = ["https://www.gov.cn/x"]) -> Data {
        let payload: [String: Any] = ["year": year, "papers": papers as Any, "days": days]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    private var valid2027Days: [[String: Any]] {
        [
            ["name": "元旦", "date": "2027-01-01", "isOffDay": true],
            ["name": "元旦", "date": "2027-01-02", "isOffDay": true],
            ["name": "元旦", "date": "2027-01-03", "isOffDay": true],
            ["name": "春节", "date": "2027-02-06", "isOffDay": true],
            ["name": "春节", "date": "2027-02-07", "isOffDay": true],
            ["name": "春节", "date": "2027-01-30", "isOffDay": false]
        ]
    }

    func testRemoteDatasetValidatesAndConverts() throws {
        let year = try HolidayRemoteUpdate.validatedYear(
            from: remoteDatasetJSON(year: 2027, days: valid2027Days),
            allowedYears: [2027]
        )

        XCTAssertEqual(year.year, 2027)
        XCTAssertEqual(year.source, .official)
        XCTAssertEqual(year.holidays.count, 2)
        let spring = year.holidays.first { $0.name == "春节" }!
        XCTAssertEqual(spring.daysOff, ["2027-02-06", "2027-02-07"])
        XCTAssertEqual(spring.workdays, ["2027-01-30"])

        // 转换结果可直接建库查询。
        let store = try HolidayStore(years: [year])
        XCTAssertEqual(store.effect(for: date(2027, 2, 6)), .restDay(name: "春节"))
        XCTAssertEqual(store.effect(for: date(2027, 1, 30)), .workday(name: "春节"))
    }

    func testRemoteDatasetRejectsAnomalies() {
        func expectFailure(_ json: Data, allowed: Set<Int> = [2027]) {
            XCTAssertThrowsError(try HolidayRemoteUpdate.validatedYear(from: json, allowedYears: allowed))
        }
        // 年份不在允许集合。
        expectFailure(remoteDatasetJSON(year: 2028, days: valid2027Days))
        // 空数据。
        expectFailure(remoteDatasetJSON(year: 2027, days: []))
        // 非法日期。
        expectFailure(remoteDatasetJSON(year: 2027, days: [["name": "x", "date": "2027-13-01", "isOffDay": true]]))
        // 日期不在年份内。
        expectFailure(remoteDatasetJSON(year: 2027, days: [["name": "x", "date": "2026-01-01", "isOffDay": true]]))
        // 重复日期。
        expectFailure(remoteDatasetJSON(year: 2027, days: [
            ["name": "x", "date": "2027-01-01", "isOffDay": true],
            ["name": "x", "date": "2027-01-01", "isOffDay": false]
        ]))
        // 休日不足。
        expectFailure(remoteDatasetJSON(year: 2027, days: [
            ["name": "x", "date": "2027-01-01", "isOffDay": true],
            ["name": "x", "date": "2027-01-02", "isOffDay": false]
        ]))
        // 天数超限。
        var tooMany: [[String: Any]] = []
        for day in 1...31 {
            tooMany.append(["name": "x", "date": String(format: "2027-01-%02d", day), "isOffDay": true])
        }
        for day in 1...31 {
            tooMany.append(["name": "x", "date": String(format: "2027-03-%02d", day), "isOffDay": true])
        }
        for day in 1...20 {
            tooMany.append(["name": "x", "date": String(format: "2027-05-%02d", day), "isOffDay": true])
        }
        expectFailure(remoteDatasetJSON(year: 2027, days: tooMany))
    }

    func testBundledWithRemoteOverridesSameYearAndKeepsOthers() throws {
        let remote = try HolidayRemoteUpdate.validatedYear(
            from: remoteDatasetJSON(year: 2027, days: valid2027Days),
            allowedYears: [2027]
        )
        let merged = HolidayStore.bundledWithRemote([remote])

        // 2026 内置官方数据仍在（春节锚点）。
        XCTAssertEqual(merged.effect(for: date(2026, 2, 17)), .restDay(name: "春节"))
        // 2027 被远程覆盖：内置官方元旦三天 -> 远程同样三天，但补班日换成了 01-30（内置为别的日期）。
        XCTAssertEqual(merged.effect(for: date(2027, 1, 2)), .restDay(name: "元旦"))
        XCTAssertEqual(merged.effect(for: date(2027, 1, 30)), .workday(name: "春节"))
        // 覆盖状态：2027 仍是 covered。
        XCTAssertEqual(merged.coverage(for: date(2027, 5, 1)), .noSpecialDay)
    }

    func testBundled2027IsNowOfficial() {
        // ADR-013：内置 2027 已随官方通知替换为 official。
        let store = HolidayStore.bundled()
        XCTAssertEqual(store.source(for: date(2027, 10, 1)), .official)
        XCTAssertEqual(store.effect(for: date(2027, 10, 1)), .restDay(name: "国庆节"))
    }

    func testNotificationBudgetReservesOtherPrefixes() {
        XCTAssertEqual(NotificationBudgetPlanner.budget(reserving: 0), NotificationBudgetPlanner.systemPendingLimit)
        XCTAssertEqual(
            NotificationBudgetPlanner.budget(reserving: 20),
            NotificationBudgetPlanner.systemPendingLimit - 20
        )
        XCTAssertEqual(NotificationBudgetPlanner.budget(reserving: 100), 0)
        XCTAssertEqual(NotificationBudgetPlanner.budget(reserving: -3), NotificationBudgetPlanner.systemPendingLimit)
    }
}
