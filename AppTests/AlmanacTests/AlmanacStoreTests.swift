import XCTest
import HolidayData
@testable import Almanac

/// App 层存储逻辑测试：闹钟三代设置迁移、简报设置恢复。
@MainActor
final class AlmanacStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testAlarmStoreLoadsV3Settings() {
        let defaults = freshDefaults()
        let template = WorkdayTemplate(kind: .custom, customWeekdays: [2, 4])
        let alarm = WorkdayAlarm(name: "早班", time: Date(), soundID: "music-box", isEnabled: true)
        let settings = AlarmSettingsForTest.v3(template: template, alarms: [alarm])
        defaults.set(settings, forKey: "workday.alarm.alarms.v3")

        let store = WorkdayAlarmStore(holidayStore: .bundledShared, defaults: defaults)

        XCTAssertEqual(store.template.kind, .custom)
        XCTAssertEqual(store.template.customWeekdays, [2, 4])
        XCTAssertEqual(store.alarms.count, 1)
        XCTAssertEqual(store.alarms.first?.name, "早班")
        XCTAssertEqual(store.alarms.first?.soundID, "music-box")
        XCTAssertTrue(store.alarms.first?.isEnabled == true)
    }

    func testAlarmStoreMigratesLegacySingleAlarm() throws {
        let defaults = freshDefaults()
        // v1：单闹钟 + 全局开关，以 JSONEncoder 编码 Data 存入（与旧版本写入方式一致）。
        let legacyPayload = try JSONEncoder().encode(LegacyV1Payload(
            isEnabled: true,
            template: WorkdayTemplate(kind: .standardFiveDay, customWeekdays: Set(2...6)),
            alarmTime: Date(timeIntervalSince1970: 1_000_000)
        ))
        defaults.set(legacyPayload, forKey: "workday.alarm.settings.v1")

        let store = WorkdayAlarmStore(holidayStore: .bundledShared, defaults: defaults)

        XCTAssertEqual(store.alarms.count, 1, "v1 设置应迁移为单闹钟")
        XCTAssertEqual(store.template.kind, .standardFiveDay)
        XCTAssertTrue(store.alarms.first?.isEnabled == true)
        XCTAssertEqual(store.alarms.first?.name, "智能闹钟")
    }

    private struct LegacyV1Payload: Codable {
        let isEnabled: Bool
        let template: WorkdayTemplate
        let alarmTime: Date
    }

    func testDailyBriefingRestoresPersistedSettings() {
        let defaults = freshDefaults()
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(true, forKey: "daily.briefing.enabled")
        defaults.set(time, forKey: "daily.briefing.time")

        let service = DailyBriefingService(defaults: defaults)

        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(
            Calendar.current.dateComponents([.hour, .minute], from: service.time),
            Calendar.current.dateComponents([.hour, .minute], from: time)
        )
    }

    func testDailyBriefingDefaultsToOffAtEight() {
        let service = DailyBriefingService(defaults: freshDefaults())

        XCTAssertFalse(service.isEnabled, "简报默认关闭")
        XCTAssertEqual(
            Calendar.current.dateComponents([.hour, .minute], from: service.time),
            DateComponents(hour: 8, minute: 0),
            "默认 08:00"
        )
    }
}

/// 测试辅助：构造 v3 存储数据（WorkdayAlarmStore 的 AlarmSettings 是私有类型）。
enum AlarmSettingsForTest {
    static func v3(template: WorkdayTemplate, alarms: [WorkdayAlarm]) -> Data {
        let encoder = JSONEncoder()
        return (try? encoder.encode(Payload(template: template, alarms: alarms))) ?? Data()
    }

    private struct Payload: Codable {
        let template: WorkdayTemplate
        let alarms: [WorkdayAlarm]
    }
}
