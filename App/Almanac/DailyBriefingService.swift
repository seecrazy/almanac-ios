import Foundation
import HolidayData
import LunarKit
import UserNotifications

/// 每日简报：预排 14 天静态内容通知（农历/节气/节日/宜忌均为日期确定性内容，可提前生成）。
/// 简报常量占用 64 条通知配额中的 ≤14 条，前缀 `daily-brief.`，与闹钟 / 里程碑互相预留。
@MainActor
final class DailyBriefingService: ObservableObject {
    static let schedulingWindowDays = 14
    static let identifierPrefix = NotificationBudgetPlanner.briefingIdentifierPrefix

    @Published var isEnabled: Bool {
        didSet { persist(); if oldValue != isEnabled { Task { await reschedule() } } }
    }
    /// 简报时间（时、分）；日期部分忽略。
    @Published var time: Date {
        didSet { persist(); Task { await reschedule() } }
    }
    @Published private(set) var authorization: WorkdayAlarmAuthorizationState = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private let enabledKey = "daily.briefing.enabled"
    private let timeKey = "daily.briefing.time"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedEnabled = defaults.object(forKey: enabledKey) as? Bool ?? false
        let storedTime = defaults.object(forKey: timeKey) as? Date
        _isEnabled = Published(initialValue: storedEnabled)
        _time = Published(initialValue: storedTime ?? Self.defaultTime())
    }

    private static func defaultTime() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    /// App 激活 / 显著时间变化时调用：刷新授权并滑动窗口。
    /// 开关打开且未决定授权时，顺带请求授权。
    func reschedule() async {
        if isEnabled, authorization == .notDetermined {
            let granted = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            authorization = granted == true ? .granted : .denied
        } else {
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

        await removePendingBriefings()
        guard isEnabled, authorization == .granted else { return }

        // 与闹钟 / 里程碑互相预留配额。
        let pending = await notificationCenter.pendingNotificationRequests()
        let reservedCount = pending
            .map(\.identifier)
            .filter {
                $0.hasPrefix(NotificationBudgetPlanner.alarmIdentifierPrefix) ||
                $0.hasPrefix(NotificationBudgetPlanner.milestoneIdentifierPrefix)
            }
            .count
        let budget = min(
            NotificationBudgetPlanner.budget(reserving: reservedCount),
            Self.schedulingWindowDays
        )

        let rules = AlmanacRuleSet.bundledShared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        for offset in 0..<max(0, budget) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            var fireComponents = calendar.dateComponents([.year, .month, .day], from: day)
            fireComponents.hour = timeComponents.hour
            fireComponents.minute = timeComponents.minute
            guard let fireDate = calendar.date(from: fireComponents), fireDate > Date() else { continue }

            let briefing = AlmanacBriefingComposer.compose(for: day, rules: rules)
            let content = UNMutableNotificationContent()
            content.title = briefing.title
            content.body = briefing.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "\(Self.identifierPrefix)\(AppFormatters.alarmIdentifierDate.string(from: day))",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
            )
            _ = try? await notificationCenter.add(request)
        }
    }

    private func removePendingBriefings() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func persist() {
        defaults.set(isEnabled, forKey: enabledKey)
        defaults.set(time, forKey: timeKey)
    }
}
