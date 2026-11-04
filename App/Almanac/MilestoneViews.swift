import SwiftUI
import MilestoneKit

struct MilestoneEditorContext: Identifiable {
    let id = UUID()
    let milestone: Milestone?
}

struct CountdownView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var milestoneStore: MilestoneStore

    @State private var editorContext: MilestoneEditorContext?

    var body: some View {
        TimelineView(.periodic(from: .now, by: milestoneStore.refreshInterval)) { timeline in
            let now = timeline.date
            let milestones = milestoneStore.sortedMilestones(at: now)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("重要日子")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundColor(palette.ink)
                        Spacer()
                        Button {
                            editorContext = MilestoneEditorContext(milestone: nil)
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(palette.accent)
                                .frame(width: 36, height: 36)
                        }
                        .accessibilityLabel("新建里程碑")
                    }
                    .padding(.horizontal, 20)

                    if milestones.isEmpty {
                        VStack(spacing: 8) {
                            Text("还没有里程碑")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(palette.ink)
                            Text("添加中考、高考、项目发布、出行或纪念日。")
                                .font(.system(size: 13))
                                .foregroundColor(palette.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(milestones) { milestone in
                                Button {
                                    editorContext = MilestoneEditorContext(milestone: milestone)
                                } label: {
                                    MilestoneCard(
                                        milestone: milestone,
                                        countdown: milestoneStore.countdown(for: milestone, at: now)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Text("里程碑保存在本机；提醒通过本地通知调度，小组件读取共享快照。")
                        .font(.system(size: 13))
                        .foregroundColor(palette.secondary)
                        .padding(.horizontal, 24)
                    Text(milestoneStore.snapshotAvailable ? "小组件快照已更新。" : "无法写入小组件快照；请确认 App Group 可用。")
                        .font(.system(size: 12))
                        .foregroundColor(milestoneStore.snapshotAvailable ? palette.secondary : palette.holidayRed)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(item: $editorContext) { context in
            MilestoneEditorView(milestone: context.milestone)
        }
    }
}

private struct MilestoneCard: View {
    @Environment(\.palette) private var palette

    let milestone: Milestone
    let countdown: MilestoneCountdown

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(milestone.category.icon) \(milestone.title)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(palette.ink)
                Text(targetText)
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                if let notes = milestone.notes.nilIfEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                        .lineLimit(1)
                }
                Text(milestone.category.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.secondary)
                if !milestone.reminders.isEmpty {
                    Text("提醒 \(milestone.reminders.count) 项")
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(countdown.primaryText)
                    .font(.system(size: countdown.primaryText.count > 6 ? 26 : 44, weight: .semibold, design: .serif))
                    .foregroundColor(countdown.isPast ? palette.makeupGray : palette.holidayRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !countdown.unitText.isEmpty {
                    Text(countdown.unitText)
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
                if let detail = countdown.detailText {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondary)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }

    private var targetText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if milestone.isAllDay {
            formatter.dateFormat = "yyyy年M月d日"
        } else {
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        }
        return formatter.string(from: milestone.targetDate)
    }
}

struct MilestoneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var milestoneStore: MilestoneStore

    let milestone: Milestone?

    @State private var title = ""
    @State private var targetDate: Date
    @State private var isAllDay = true
    @State private var category: MilestoneCategory = .custom
    @State private var notes = ""
    @State private var reminders: [MilestoneReminder] = []
    @State private var deleteConfirmationIsPresented = false

    private let calendar = Calendar.current

    init(milestone: Milestone?) {
        self.milestone = milestone

        let defaultDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        if let milestone {
            _title = State(initialValue: milestone.title)
            _targetDate = State(initialValue: milestone.targetDate)
            _isAllDay = State(initialValue: milestone.isAllDay)
            _category = State(initialValue: milestone.category)
            _notes = State(initialValue: milestone.notes)
            _reminders = State(initialValue: milestone.reminders)
        } else {
            _targetDate = State(initialValue: defaultDate)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    Picker("类型", selection: $category) {
                        ForEach(MilestoneCategory.allCases) { item in
                            Text("\(item.icon) \(item.title)").tag(item)
                        }
                    }
                    Toggle("全天", isOn: $isAllDay)

                    if isAllDay {
                        DatePicker(
                            "日期",
                            selection: $targetDate,
                            displayedComponents: [.date]
                        )
                    } else {
                        DatePicker(
                            "日期和时间",
                            selection: $targetDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("备注") {
                    TextField("备注（可选）", text: $notes)
                }

                Section("提醒") {
                    ForEach(MilestoneReminderKind.allCases) { kind in
                        Toggle(kind.title, isOn: reminderBinding(for: kind))
                    }

                    switch milestoneStore.notificationAuthorization {
                    case .granted:
                        Text("通知已授权，将按计划响铃。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                    case .notDetermined:
                        Text(hasEnabledReminders ? "保存后宜历会请求通知权限。" : "启用提醒后，保存时会请求通知权限。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                    case .denied:
                        Text("通知未授权；提醒设置会保存，但不会响铃。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.holidayRed)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(milestone == nil ? "保存里程碑" : "保存修改")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)

                    if milestone != nil {
                        Button(role: .destructive) {
                            deleteConfirmationIsPresented = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除里程碑")
                                Spacer()
                            }
                        }
                    }
                } footer: {
                    Text("里程碑保存在本机，不写入系统日历；提醒通过本地通知调度。")
                }
            }
            .navigationTitle(milestone == nil ? "新建里程碑" : "编辑里程碑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("删除这个里程碑？", isPresented: $deleteConfirmationIsPresented) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let milestone {
                        Task {
                            await milestoneStore.remove(milestone)
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("删除后无法在宜历内撤销。")
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasEnabledReminders: Bool {
        reminders.contains { $0.isEnabled }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDate = isAllDay
            ? calendar.startOfDay(for: targetDate)
            : targetDate
        let now = Date()
        let updated = Milestone(
            id: milestone?.id ?? UUID(),
            title: trimmedTitle,
            targetDate: normalizedDate,
            isAllDay: isAllDay,
            category: category,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: milestone?.createdAt ?? now,
            reminders: reminders
        )
        Task {
            await milestoneStore.save(updated)
            dismiss()
        }
    }

    private func reminderBinding(for kind: MilestoneReminderKind) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                reminders.first { $0.kind == kind }?.isEnabled ?? false
            },
            set: { isEnabled in
                if let index = reminders.firstIndex(where: { $0.kind == kind }) {
                    if isEnabled {
                        reminders[index].isEnabled = true
                    } else {
                        reminders.remove(at: index)
                    }
                } else if isEnabled {
                    reminders.append(MilestoneReminder(kind: kind, isEnabled: true))
                }
            }
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
