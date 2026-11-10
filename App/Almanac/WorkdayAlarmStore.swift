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
    case birdSong = "bird-song"
    case musicBox = "music-box"
    case deepBell = "deep-bell"
    case digitalBeep = "digital-beep"
    case sunrise = "sunrise"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault: return "系统默认"
        case .morningChime: return "清晨钟声"
        case .doublePulse: return "双响脉冲"
        case .lightBell: return "轻快铃"
        case .birdSong: return "晨间鸟鸣"
        case .musicBox: return "八音盒"
        case .deepBell: return "古钟"
        case .digitalBeep: return "电子音"
        case .sunrise: return "晨光渐强"
        }
    }

    var notificationSound: UNNotificationSound {
        switch self {
        case .systemDefault:
            return .default
        case .morningChime, .doublePulse, .lightBell, .birdSong,
             .musicBox, .deepBell, .digitalBeep, .sunrise:
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

    static let identifierPrefix = NotificationBudgetPlanner.alarmIdentifierPrefix
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

    /// 60 天计划中受通知配额约束实际可调度的部分。
    @Published private(set) var scheduledOccurrenceCount = 0

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

    /// App 激活 / 系统显著时间变化时重排：不请求授权、不落盘。
    func reschedule() async {
        await refreshAuthorization()
        await replacePendingNotifications()
    }

    private func replacePendingNotifications() async {
        let anyAlarmEnabled = alarms.contains { $0.isEnabled }
        let reference = Date()
        // 完整 60 天计划：保活计时器据此兜底响铃，不受通知配额约束。
        let plannedOccurrences = WorkdayAlarmPlanner.occurrences(
            alarms: alarms,
            template: template,
            holidays: holidayStore,
            from: reference
        )
        AlarmKeepAlive.shared.sync(
            occurrences: plannedOccurrences,
            anyAlarmEnabled: anyAlarmEnabled
        )

        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard authorization == .granted else {
            scheduledOccurrenceCount = 0
            return
        }

        // 里程碑与简报共用 64 条待发上限，调度前须为其预留。
        let reservedCount = pending
            .map(\.identifier)
            .filter {
                $0.hasPrefix(NotificationBudgetPlanner.milestoneIdentifierPrefix) ||
                $0.hasPrefix(NotificationBudgetPlanner.briefingIdentifierPrefix)
            }
            .count
        let budget = NotificationBudgetPlanner.budget(reserving: reservedCount)

        let occurrences = NotificationBudgetPlanner.trimming(plannedOccurrences, budget: budget)
        scheduledOccurrenceCount = occurrences.count

        // 进程内兜底响铃：保活 + 计时器使用未裁剪的完整计划（不受通知配额约束）。
        AlarmKeepAlive.shared.sync(
            occurrences: plannedOccurrences,
            anyAlarmEnabled: alarms.contains { $0.isEnabled }
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
            // 打穿专注模式；userInfo 供通知代理进入全屏响铃页。
            content.interruptionLevel = .timeSensitive
            content.userInfo = [
                "alarmName": alarmTitle.isEmpty ? "智能闹钟" : alarmTitle,
                "soundID": occurrence.alarm.soundID
            ]

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
        AppFormatters.alarmIdentifierDate.string(from: date)
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
        // 闹钟前台到点：进入全屏响铃页循环响铃（无视静音键），横幅本身不带系统音避免叠加。
        if isAlarmNotification(notification) {
            startRinging(notification)
            completionHandler([.banner, .list])
            return
        }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 用户点按闹钟通知（含锁屏 / 通知中心）：打开即响铃。
        if isAlarmNotification(response.notification) {
            startRinging(response.notification)
        }
        completionHandler()
    }

    private func isAlarmNotification(_ notification: UNNotification) -> Bool {
        notification.request.identifier.hasPrefix(NotificationBudgetPlanner.alarmIdentifierPrefix)
    }

    private func startRinging(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let alarmName = (userInfo["alarmName"] as? String) ?? notification.request.content.title
        let soundID = (userInfo["soundID"] as? String) ?? SmartAlarmSound.systemDefault.rawValue

        Task { @MainActor in
            AlarmRingingController.shared.start(alarmName: alarmName, soundID: soundID)
        }
    }
}
