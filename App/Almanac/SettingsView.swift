import SwiftUI
import HolidayData
import UserNotifications

struct SettingsView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService
    @StateObject private var workdayAlarmStore: WorkdayAlarmStore

    @AppStorage("showLunar") private var showLunar = true
    @AppStorage("showSolarTerms") private var showSolarTerms = true
    @AppStorage("showHuangLi") private var showHuangLi = false
    @AppStorage("month.week.start.day") private var weekStartDayRaw = WeekStartDay.monday.rawValue

    private let holidayStore: HolidayStore

    init() {
        let holidayStore = HolidayStore.bundled()
        self.holidayStore = holidayStore
        _workdayAlarmStore = StateObject(
            wrappedValue: WorkdayAlarmStore(holidayStore: holidayStore)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("设置")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundColor(palette.ink)

                VStack(spacing: 0) {
                    toggleRow("农历日期", binding: $showLunar)
                    Divider().background(palette.separator)
                    toggleRow("二十四节气", binding: $showSolarTerms)
                    Divider().background(palette.separator)
                    toggleRow("黄历（宜忌/冲煞）", binding: $showHuangLi)
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                VStack(alignment: .leading, spacing: 12) {
                    Text("节假日数据")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)

                    if holidayStore.statuses.isEmpty {
                        Text("节假日数据未加载")
                            .font(.system(size: 13))
                            .foregroundColor(palette.secondary)
                    } else {
                        ForEach(holidayStore.statuses, id: \.year) { status in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(status.year) · \(status.source.title)")
                                    .font(.system(size: 13))
                                    .foregroundColor(palette.ink)
                                if let sourceName = status.sourceName {
                                    Text(sourceName)
                                        .font(.system(size: 12))
                                        .foregroundColor(palette.secondary)
                                }
                                if let issuedAt = status.issuedAt {
                                    Text("更新时间：\(issuedAt)")
                                        .font(.system(size: 12))
                                        .foregroundColor(palette.secondary)
                                }
                            }
                        }
                    }

                    if !holidayStore.loadErrors.isEmpty {
                        Text("部分年度数据加载失败，已按未覆盖处理。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.holidayRed)
                    }

                    Text("当前内置数据仍为示例；官方通知发布后按数据管道更新。")
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                VStack(alignment: .leading, spacing: 12) {
                    Text("月视图")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)
                    Text("周起始日")
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                    Picker("周起始日", selection: $weekStartDayRaw) {
                        ForEach(WeekStartDay.allCases) { day in
                            Text(day.title).tag(day.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("周起始日")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                workdayAlarmCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("系统日历")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(palette.ink)
                    Text(accessText)
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                    if eventService.accessState == .notDetermined {
                        Button {
                            Task { await eventService.requestAccessIfNeeded() }
                        } label: {
                            Text("允许访问")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(palette.accent))
                        }
                    } else if eventService.accessState == .denied {
                        Text("请到系统设置 > 隐私与安全性 > 日历中开启权限。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                    }
                    if let error = eventService.lastErrorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(palette.holidayRed)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))

                Text("黄历默认关闭；开关控制日详情中的黄历面板。当前版本设置不参与同步。")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            }
            .padding(20)
        }
        .background(palette.background.ignoresSafeArea())
    }

    private func toggleRow(_ title: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(palette.ink)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var accessText: String {
        switch eventService.accessState {
        case .granted: return "已接入 EventKit，日程来自系统日历。"
        case .denied: return "未授权读取系统日历。"
        case .notDetermined: return "尚未请求日历权限。"
        }
    }

    private var workdayAlarmCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("智能闹钟")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { workdayAlarmStore.isEnabled },
                    set: { isEnabled in
                        workdayAlarmStore.isEnabled = isEnabled
                        Task { await workdayAlarmStore.sync() }
                    }
                ))
                .labelsHidden()
            }

            Picker("工作日模板", selection: Binding(
                get: { workdayAlarmStore.template.kind },
                set: { kind in
                    workdayAlarmStore.select(kind: kind)
                    Task { await workdayAlarmStore.sync() }
                }
            )) {
                ForEach(WorkdayTemplateKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            if workdayAlarmStore.template.kind == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义工作日")
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                    ForEach(1...7, id: \.self) { weekday in
                        Toggle(
                            WorkdayResolver.weekdayName(for: weekday),
                            isOn: Binding(
                                get: {
                                    workdayAlarmStore.template.customWeekdays.contains(weekday)
                                },
                                set: { isSelected in
                                    workdayAlarmStore.setCustomWeekday(weekday, isSelected: isSelected)
                                    Task { await workdayAlarmStore.sync() }
                                }
                            )
                        )
                    }
                }
            }

            DatePicker(
                "响铃时间",
                selection: Binding(
                    get: { workdayAlarmStore.alarmTime },
                    set: { date in
                        workdayAlarmStore.alarmTime = date
                        Task { await workdayAlarmStore.sync() }
                    }
                ),
                displayedComponents: [.hourAndMinute]
            )

            let plans = workdayAlarmStore.plans
            if plans.isEmpty {
                Text("当前模板没有工作日。")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
            } else {
                Text("未来 60 天预览")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(palette.ink)

                ForEach(plans.prefix(10), id: \.date) { plan in
                    workdayPlanRow(plan)
                }
                if plans.count > 10 {
                    Text("其余 \(plans.count - 10) 天按同一规则调度。")
                        .font(.system(size: 11))
                        .foregroundColor(palette.secondary)
                }
            }

            switch workdayAlarmStore.authorization {
            case .granted:
                Text("通知已授权，智能闹钟按计划调度。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            case .notDetermined:
                Text("开启开关后会请求通知权限。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            case .denied:
                Text("通知未授权；预览可用，但不会响铃。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.holidayRed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
        .task {
            await workdayAlarmStore.refreshAuthorization()
            await workdayAlarmStore.sync(shouldRequestAuthorization: false)
        }
    }

    private func workdayPlanRow(_ plan: WorkdayPlan) -> some View {
        HStack(spacing: 12) {
            Text(plan.date, format: .dateTime.month().day().weekday())
                .font(.system(size: 13))
                .foregroundColor(palette.ink)
            Spacer()
            Text(plan.reason)
                .font(.system(size: 11))
                .foregroundColor(palette.secondary)
                .lineLimit(1)
            Text(plan.shouldRing
                ? plan.date.formatted(.dateTime.hour().minute())
                : "关闭")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(plan.shouldRing ? palette.accent : palette.secondary)
        }
    }
}

enum WorkdayAlarmAuthorizationState: Equatable {
    case notDetermined
    case granted
    case denied
}

@MainActor
final class WorkdayAlarmStore: ObservableObject {
    @Published var isEnabled: Bool
    @Published var template: WorkdayTemplate
    @Published var alarmTime: Date
    @Published private(set) var authorization: WorkdayAlarmAuthorizationState = .notDetermined

    private let holidayStore: HolidayStore
    private let defaults: UserDefaults
    private let storageKey = "workday.alarm.settings.v1"
    private let notificationCenter = UNUserNotificationCenter.current()

    private static let identifierPrefix = "workday-alarm."

    var plans: [WorkdayPlan] {
        WorkdayResolver.plan(
            from: Date(),
            days: WorkdayResolver.maximumPlanDays,
            template: template,
            holidays: holidayStore
        )
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

        if let data = defaults.data(forKey: "workday.alarm.settings.v1"),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            isEnabled = settings.isEnabled
            template = settings.template
            alarmTime = settings.alarmTime
        } else {
            isEnabled = false
            template = .standard
            alarmTime = defaultTime
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
        let shouldRequest = shouldRequestAuthorization ?? isEnabled
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

        guard isEnabled, authorization == .granted else { return }
        let reference = Date()
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
        var scheduleCalendar = Calendar(identifier: .gregorian)
        scheduleCalendar.timeZone = LunarCalendarShanghai.timezone

        for plan in plans where plan.shouldRing {
            guard let fireDate = scheduleCalendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: plan.date
            ), fireDate > reference else { continue }

            var components = scheduleCalendar.dateComponents([.year, .month, .day], from: fireDate)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            components.timeZone = LunarCalendarShanghai.timezone

            let content = UNMutableNotificationContent()
            content.title = "智能闹钟"
            content.body = plan.reason
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "workday-alarm.\(Self.identifierDate(for: plan.date))",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            _ = try? await notificationCenter.add(request)
        }
    }

    private func persist() {
        let settings = Settings(
            isEnabled: isEnabled,
            template: template,
            alarmTime: alarmTime
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

    private struct Settings: Codable {
        let isEnabled: Bool
        let template: WorkdayTemplate
        let alarmTime: Date
    }
}
