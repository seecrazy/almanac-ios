import SwiftUI
import HolidayData

struct AlarmView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var store: WorkdayAlarmStore

    @State private var expandedAlarmID: UUID?
    @State private var showFullPreview = false
    @State private var syncDebounceTask: Task<Void, Never>?

    private var occurrences: [WorkdayAlarmOccurrence] { store.occurrences }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ruleCard
                alarmList
                addButton
                previewSection
                authorizationFooter
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .task {
            await store.refreshAuthorization()
            await store.sync(shouldRequestAuthorization: false)
        }
        .onChange(of: store.alarms) { _ in
            // 名称 / 时间编辑每字符都会写 store；全量重排通知开销大，防抖合并。
            syncDebounceTask?.cancel()
            syncDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                await store.sync()
            }
        }
        .onDisappear {
            // 防抖窗口内退出立即冲刷，避免丢最后一次编辑。
            syncDebounceTask?.cancel()
            syncDebounceTask = nil
            Task { await store.sync() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("闹钟")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundColor(palette.ink)
                Text("法定休息日自动静默，调休补班日自动开启")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)
            }
            Spacer()
            let enabledCount = store.alarms.filter(\.isEnabled).count
            Text(enabledCount == 0 ? "未启用" : "\(enabledCount)/\(store.alarms.count) 启用")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(enabledCount == 0 ? palette.secondary : palette.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(palette.card))
        }
    }

    private var ruleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.accent)
                Text("工作日规则")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.ink)
                Spacer()
                Text("休 / 班优先")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.background))
            }

            HStack(spacing: 8) {
                ruleOption(.standardFiveDay, title: "工作日", detail: "周一–周五")
                ruleOption(.singleRestDay, title: "单休", detail: "周一–周六")
            }
            HStack(spacing: 8) {
                ruleOption(.sixDayWeek, title: "六天工作", detail: "周一–周日")
                ruleOption(.custom, title: "自定义", detail: "自选周几")
            }

            if store.template.kind == .custom {
                VStack(alignment: .leading, spacing: 10) {
                    Text("自选工作日")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(palette.secondary)
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { weekday in
                            let selected = store.template.customWeekdays.contains(weekday)
                            Button {
                                store.setCustomWeekday(weekday, isSelected: !selected)
                                Task { await store.sync() }
                            } label: {
                                Text(String(WorkdayResolver.weekdayName(for: weekday).suffix(1)))
                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                    .foregroundColor(selected ? .white : palette.secondary)
                                    .frame(width: 34, height: 30)
                                    .background(Capsule().fill(selected ? palette.accent : palette.background))
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            Text("优先级：官方休息日 > 官方补班日 > 每周规则")
                .font(.system(size: 11))
                .foregroundColor(palette.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.separator, lineWidth: 1))
        )
    }

    private func ruleOption(
        _ kind: WorkdayTemplateKind,
        title: String,
        detail: String
    ) -> some View {
        let selected = store.template.kind == kind
        return Button {
            store.select(kind: kind)
            Task { await store.sync() }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(selected ? .white : palette.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(selected ? .white.opacity(0.82) : palette.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? palette.accent : palette.background))
        }
    }

    private var alarmList: some View {
        VStack(spacing: 10) {
            ForEach(store.alarms) { alarm in
                AlarmCard(
                    alarm: alarmBinding(for: alarm),
                    isExpanded: expandedAlarmID == alarm.id,
                    canDelete: store.alarms.count > 1,
                    nextFireDate: store.occurrences.first { $0.alarm.id == alarm.id }?.fireDate,
                    palette: palette,
                    onToggleExpanded: {
                        expandedAlarmID = expandedAlarmID == alarm.id ? nil : alarm.id
                    },
                    onDelete: {
                        store.removeAlarm(alarm)
                        if expandedAlarmID == alarm.id { expandedAlarmID = nil }
                    }
                )
            }
        }
    }

    private var addButton: some View {
        let isDisabled = store.alarms.count >= WorkdayAlarmPlanner.maximumAlarmCount
        return Button {
            store.addAlarm()
            Task { await store.sync() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text(isDisabled ? "最多 8 个闹钟" : "添加闹钟")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isDisabled ? palette.secondary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(isDisabled ? palette.card : palette.accent))
        }
        .disabled(isDisabled)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(palette.accent)
                Text("未来 60 天")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.ink)
                Spacer()
                if !occurrences.isEmpty {
                    Text(scheduledSummaryText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.secondary)
                }
            }

            if store.scheduledOccurrenceCount == 0, !occurrences.isEmpty {
                Text("通知配额已被其它提醒占满，闹钟暂无法调度。")
                    .font(.system(size: 12))
                    .foregroundColor(palette.holidayRed)
            } else if store.scheduledOccurrenceCount < occurrences.count {
                Text("受 iOS 64 条待发通知上限约束，实际调度前 \(store.scheduledOccurrenceCount) 次；打开 App 会自动续排。")
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondary)
            }

            if let next = occurrences.first {
                nextOccurrenceCard(next)
            } else {
                Text("当前规则下 60 天内没有触发计划。")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(palette.card))
            }

            ForEach(occurrences.prefix(showFullPreview ? occurrences.count : 5), id: \.self) { occurrence in
                occurrenceRow(occurrence)
            }

            if occurrences.count > 5 {
                Button(showFullPreview ? "收起计划" : "显示全部计划") {
                    showFullPreview.toggle()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(palette.accent)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(palette.card))
    }

    private var scheduledSummaryText: String {
        store.scheduledOccurrenceCount < occurrences.count
            ? "计划 \(occurrences.count) 次 / 调度 \(store.scheduledOccurrenceCount) 次"
            : "\(occurrences.count) 次"
    }

    private func nextOccurrenceCard(_ occurrence: WorkdayAlarmOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("下一次响铃")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(palette.accent)
            Text(occurrence.fireDate, format: .dateTime.month().day().weekday().hour().minute())
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(palette.ink)
            HStack(spacing: 6) {
                Text(occurrence.alarm.name.isEmpty ? "闹钟" : occurrence.alarm.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.accent))
                Text(occurrence.plan.reason)
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.background))
    }

    private func occurrenceRow(_ occurrence: WorkdayAlarmOccurrence) -> some View {
        HStack(spacing: 10) {
            Text(occurrence.fireDate, format: .dateTime.month().day().weekday())
                .font(.system(size: 13))
                .foregroundColor(palette.ink)
            Spacer()
            Text(occurrence.fireDate, format: .dateTime.hour().minute())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(palette.accent)
            Text(occurrence.alarm.name.isEmpty ? "闹钟" : occurrence.alarm.name)
                .font(.system(size: 11))
                .foregroundColor(palette.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private var authorizationFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: authorizationIcon)
                .foregroundColor(authorizationColor)
            Text(authorizationText)
                .font(.system(size: 12))
                .foregroundColor(authorizationColor)
            Spacer()
            if store.authorization == .denied {
                OpenSettingsLink()
            }
        }
        .padding(.horizontal, 4)
    }

    private var authorizationIcon: String {
        switch store.authorization {
        case .granted: return "checkmark.circle.fill"
        case .notDetermined: return "bell.badge"
        case .denied: return "bell.slash.fill"
        }
    }

    private var authorizationColor: Color {
        switch store.authorization {
        case .granted: return palette.solarGreen
        case .notDetermined: return palette.secondary
        case .denied: return palette.holidayRed
        }
    }

    private var authorizationText: String {
        switch store.authorization {
        case .granted: return "通知已授权，按计划响铃。"
        case .notDetermined: return "开启任意闹钟后会请求通知权限；规则切换不会开启闹钟。"
        case .denied: return "通知未授权；预览可用，但不会响铃。"
        }
    }

    private func alarmBinding(for alarm: WorkdayAlarm) -> Binding<WorkdayAlarm> {
        Binding {
            store.alarms.first { $0.id == alarm.id } ?? alarm
        } set: { newValue in
            if let index = store.alarms.firstIndex(where: { $0.id == alarm.id }) {
                store.alarms[index] = newValue
            }
        }
    }
}

private struct AlarmCard: View {
    @Binding var alarm: WorkdayAlarm
    let isExpanded: Bool
    let canDelete: Bool
    /// 该闹钟下一次实际响铃时间；nil = 当前规则下不会响铃。作为"修改已保存"的可见反馈。
    let nextFireDate: Date?
    let palette: Palette
    let onToggleExpanded: () -> Void
    let onDelete: () -> Void

    @State private var soundSheetIsPresented = false

    private var currentSoundTitle: String {
        SmartAlarmSound(rawValue: alarm.soundID)?.title ?? "系统默认"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggleExpanded) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppFormatters.hhmm.string(from: alarm.time))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(alarm.isEnabled ? palette.ink : palette.secondary.opacity(0.65))
                        Text(nameLine)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(palette.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.secondary)
                    Toggle("", isOn: $alarm.isEnabled)
                        .labelsHidden()
                        .tint(palette.accent)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("闹钟名称", text: $alarm.name)
                        .font(.system(size: 14, weight: .medium))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(palette.background))

                    DatePicker("时间", selection: $alarm.time, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 104)
                        .background(RoundedRectangle(cornerRadius: 14).fill(palette.background))

                    Button {
                        soundSheetIsPresented = true
                    } label: {
                        HStack {
                            Text("铃声")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(palette.ink)
                            Spacer()
                            Text(currentSoundTitle)
                                .font(.system(size: 13))
                                .foregroundColor(palette.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(palette.secondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 14).fill(palette.background))
                    }
                    .accessibilityLabel("选择铃声，当前\(currentSoundTitle)")

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(palette.solarGreen)
                        Text(saveStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                    }

                    if canDelete {
                        Button(action: onDelete) {
                            Label("删除闹钟", systemImage: "trash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(palette.holidayRed)
                        }
                    }
                }
                .sheet(isPresented: $soundSheetIsPresented) {
                    AlarmSoundPickerSheet(selection: $alarm.soundID)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.separator, lineWidth: 1))
        )
        .onChange(of: isExpanded) { expanded in
            // 收起卡片即停止试听，不留尾巴。
            if !expanded { AlarmAudio.stopPreview() }
        }
    }

    private var nameLine: String {
        let name = alarm.name.isEmpty ? "闹钟" : alarm.name
        guard alarm.isEnabled else {
            return "\(name) · 未启用"
        }
        guard let next = nextFireDate else {
            return "\(name) · 当前规则下不会响铃"
        }
        return "\(name) · 下次响铃 \(AppFormatters.monthDayTime.string(from: next))"
    }

    private var saveStatusText: String {
        guard alarm.isEnabled else { return "修改自动保存；闹钟未启用，不会调度" }
        guard let next = nextFireDate else { return "修改自动保存；当前规则下不会响铃" }
        return "修改自动保存 · 下次响铃 \(AppFormatters.monthDayWeekday.string(from: next)) \(AppFormatters.hhmm.string(from: next))"
    }
}
