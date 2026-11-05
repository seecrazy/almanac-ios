import Foundation
import HolidayData
import UserNotifications

enum WorkdayAlarmAuthorizationState: Equatable {
    case notDetermined
    case granted
    case denied
}

enum SmartAlarmSound: String, CaseIterable, Identifiable {
    case systemDefault
    case morningChime = "morning-chime"
    case doublePulse = "double-pulse"
    case lightBell = "light-bell"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault: return "系统默认"
        case .morningChime: return "清晨钟声"
        case .doublePulse: return "双响脉冲"
        case .lightBell: return "轻快铃"
        }
    }

    var notificationSound: UNNotificationSound {
        switch self {
        case .systemDefault:
            return .default
        case .morningChime, .doublePulse, .lightBell:
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(rawValue).caf"))
        }
    }
}

@MainActor
final class WorkdayAlarmStore: ObservableObject {
    @Published var template: WorkdayTemplate
    @Published var alarms: [WorkdayAlarm]
    @Published private(set) var authorization: WorkdayAlarmAuthorizationState = .notDetermined

    private let holidayStore: HolidayStore
    private let defaults: UserDefaults
    private let legacyStorageKey = "workday.alarm.settings.v1"
    private let previousStorageKey = "workday.alarm.alarms.v2"
    private let storageKey = "workday.alarm.alarms.v3"
    private let notificationCenter = UNUserNotificationCenter.current()

    private static let identifierPrefix = "workday-alarm."
    private static let legacyAlarmID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    var occurrences: [WorkdayAlarmOccurrence] {
        WorkdayAlarmPlanner.occurrences(
            alarms: alarms,
            template: template,
            holidays: holidayStore,
            from: Date()
        )
    }

    var upcomingOccurrences: [WorkdayAlarmOccurrence] {
        Array(occurrences.prefix(10))
    }

    init(
        holidayStore: HolidayStore,
        defaults: UserDefaults = .standard
    ) {
        self.holidayStore = holidayStore
        self.defaults = defaults

        var defaultCalendar = Calendar(identifier: .gregorian)
        defaultCalendar.timeZone = .current
        let defaultTime = defaultCalendar.date(
            bySettingHour: 7,
            minute: 30,
            second: 0,
            of: Date()
        ) ?? Date()

        if let data = defaults.data(forKey: storageKey),
           let settings = try? JSONDecoder().decode(AlarmSettings.self, from: data) {
            template = settings.template
            alarms = settings.alarms
        } else if let data = defaults.data(forKey: previousStorageKey),
                  let settings = try? JSONDecoder().decode(PreviousAlarmSettings.self, from: data) {
            template = settings.template
            alarms = settings.alarms.map {
                var alarm = $0
                alarm.isEnabled = settings.isEnabled && alarm.isEnabled
                return alarm
            }
        } else if let data = defaults.data(forKey: legacyStorageKey),
                  let settings = try? JSONDecoder().decode(LegacyAlarmSettings.self, from: data) {
            template = settings.template
            alarms = [
                WorkdayAlarm(
                    id: Self.legacyAlarmID,
                    name: "智能闹钟",
                    time: settings.alarmTime,
                    soundID: SmartAlarmSound.systemDefault.rawValue,
                    isEnabled: settings.isEnabled
                )
            ]
        } else {
            template = .standard
            alarms = [
                WorkdayAlarm(
                    name: "上班闹钟",
                    time: defaultTime,
                    soundID: SmartAlarmSound.systemDefault.rawValue,
                    isEnabled: false
                )
            ]
        }
    }

    func select(kind: WorkdayTemplateKind) {
        switch kind {
        case .standardFiveDay:
            template = .standard
        case .singleRestDay:
            template = .singleRest
        case .sixDayWeek:
            template = .sixDay
        case .custom:
            let weekdays = template.kind == .custom
                ? template.customWeekdays
                : Set(2...6)
            template = WorkdayTemplate(kind: .custom, customWeekdays: weekdays)
        }
    }

    func setCustomWeekday(_ weekday: Int, isSelected: Bool) {
        guard template.kind == .custom else { return }
        var weekdays = template.customWeekdays
        if isSelected {
            weekdays.insert(weekday)
        } else {
            weekdays.remove(weekday)
        }
        template.customWeekdays = weekdays
    }

    func addAlarm() {
        guard alarms.count < WorkdayAlarmPlanner.maximumAlarmCount else { return }
        let fallback = alarms.last?.time ?? Date()
        let nextTime = Calendar.current.date(byAdding: .minute, value: 30, to: fallback) ?? fallback
        alarms.append(WorkdayAlarm(name: "闹钟 \(alarms.count + 1)", time: nextTime))
    }

    func removeAlarm(_ alarm: WorkdayAlarm) {
        guard alarms.count > 1 else { return }
        alarms.removeAll { $0.id == alarm.id }
    }

    func refreshAuthorization() async {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorization = .granted
        case .notDetermined:
            authorization = .notDetermined
        default:
            authorization = .denied
        }
    }

    func sync(shouldRequestAuthorization: Bool? = nil) async {
        persist()
        let shouldRequest = shouldRequestAuthorization ?? alarms.contains { $0.isEnabled }
        if shouldRequest {
            let granted = try? await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            authorization = granted == true ? .granted : .denied
        } else {
            await refreshAuthorization()
        }

        await replacePendingNotifications()
    }

    private func replacePendingNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard authorization == .granted else { return }

        let reference = Date()
        let occurrences = WorkdayAlarmPlanner.occurrences(
            alarms: alarms,
            template: template,
            holidays: holidayStore,
            from: reference
        )

        for occurrence in occurrences {
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: occurrence.fireDate
            )
            components.timeZone = Calendar.current.timeZone

            let alarmTitle = occurrence.alarm.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = UNMutableNotificationContent()
            content.title = alarmTitle.isEmpty ? "智能闹钟" : alarmTitle
            content.body = occurrence.plan.reason
            content.sound = SmartAlarmSound(rawValue: occurrence.alarm.soundID)?.notificationSound
                ?? UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: [
                    Self.identifierPrefix,
                    occurrence.alarm.id.uuidString,
                    Self.identifierDate(for: occurrence.plan.date)
                ].joined(separator: "."),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            _ = try? await notificationCenter.add(request)
        }
    }

    private func persist() {
        let settings = AlarmSettings(
            template: template,
            alarms: alarms
        )
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func identifierDate(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = LunarCalendarShanghai.timezone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = LunarCalendarShanghai.timezone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private struct AlarmSettings: Codable {
        let template: WorkdayTemplate
        let alarms: [WorkdayAlarm]
    }

    private struct PreviousAlarmSettings: Codable {
        let isEnabled: Bool
        let template: WorkdayTemplate
        let alarms: [WorkdayAlarm]
    }

    private struct LegacyAlarmSettings: Codable {
        let isEnabled: Bool
        let template: WorkdayTemplate
        let alarmTime: Date
    }
}

final class AlarmNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlarmNotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
