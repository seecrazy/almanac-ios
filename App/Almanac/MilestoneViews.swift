import SwiftUI
import MilestoneKit
import LunarKit

struct MilestoneEditorContext: Identifiable {
    let id = UUID()
    let milestone: Milestone?
}

struct AnniversaryEditorContext: Identifiable {
    let id = UUID()
    let anniversary: Anniversary?
}

struct CountdownView: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var milestoneStore: MilestoneStore
    @EnvironmentObject private var router: AppRouter

    @State private var editorContext: MilestoneEditorContext?
    @State private var anniversaryEditorContext: AnniversaryEditorContext?
    @State private var importSheetIsPresented = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: milestoneStore.refreshInterval)) { timeline in
            let now = timeline.date
            let milestones = milestoneStore.sortedMilestones(at: now)
            let anniversaryOccurrences = milestoneStore.sortedAnniversaryOccurrences(at: now)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("倒计时")
                            .font(.system(size: 34, weight: .bold, design: .serif))
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

                    let stats = countdownStats(milestones: milestones, now: now)
                    statisticRow(stats)

                    anniversarySection(occurrences: anniversaryOccurrences)

                    if milestones.isEmpty && anniversaryOccurrences.isEmpty {
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
                        milestoneList(milestones: milestones, now: now)
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
        .sheet(item: $anniversaryEditorContext) { context in
            AnniversaryEditorView(anniversary: context.anniversary)
        }
        .sheet(isPresented: $importSheetIsPresented) {
            ContactImportSheet()
        }
        .onReceive(router.$pendingMilestoneID) { id in
            guard let id else { return }
            if let milestone = milestoneStore.milestones.first(where: { $0.id == id }) {
                editorContext = MilestoneEditorContext(milestone: milestone)
            }
            router.pendingMilestoneID = nil
        }
        .onReceive(router.$pendingAnniversaryID) { id in
            guard let id else { return }
            if let anniversary = milestoneStore.anniversaries.first(where: { $0.id == id }) {
                anniversaryEditorContext = AnniversaryEditorContext(anniversary: anniversary)
            }
            router.pendingAnniversaryID = nil
        }
    }

    private func milestoneList(milestones: [Milestone], now: Date) -> some View {
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

    private func statisticRow(_ stats: (upcoming: Int, today: Int, past: Int)) -> some View {
        HStack(spacing: 10) {
            statisticCard(title: "即将到来", value: stats.upcoming, color: palette.accent)
            statisticCard(title: "今天", value: stats.today, color: palette.holidayRed)
            statisticCard(title: "已过期", value: stats.past, color: palette.makeupGray)
        }
        .padding(.horizontal, 20)
    }

    private func statisticCard(
        title: String,
        value: Int,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.card))
    }

    private func countdownStats(
        milestones: [Milestone],
        now: Date
    ) -> (upcoming: Int, today: Int, past: Int) {
        let today = Calendar.current.startOfDay(for: now)
        var upcoming = 0
        var todayCount = 0
        var past = 0
        for milestone in milestones {
            let date = milestone.effectiveSortDate
            if date < today {
                past += 1
            } else if Calendar.current.isDate(date, inSameDayAs: today) {
                todayCount += 1
            } else {
                upcoming += 1
            }
        }
        return (upcoming, todayCount, past)
    }

    private func anniversarySection(occurrences: [AnniversaryOccurrence]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("生日 / 纪念日")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(palette.ink)
                Spacer()
                Button {
                    importSheetIsPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("从通讯录导入生日")
                Button {
                    anniversaryEditorContext = AnniversaryEditorContext(anniversary: nil)
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("新建生日或纪念日")
            }
            .padding(.horizontal, 20)

            if occurrences.isEmpty {
                Text("还没有生日或纪念日；可手动添加阳历或农历日期。")
                    .font(.system(size: 13))
                    .foregroundColor(palette.secondary)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(occurrences) { occurrence in
                        Button {
                            anniversaryEditorContext = AnniversaryEditorContext(anniversary: occurrence.anniversary)
                        } label: {
                            AnniversaryCard(occurrence: occurrence)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct MilestoneCard: View {
    @Environment(\.palette) private var palette

    let milestone: Milestone
    let countdown: MilestoneCountdown

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("\(milestone.category.icon)")
                    .font(.system(size: 14))
                Text(milestone.category.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(categoryColor.opacity(0.12)))

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(countdown.primaryText)
                        .font(.system(size: countdown.primaryText.count > 5 ? 24 : 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(numberColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(countdown.unitText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(milestone.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(palette.ink)
                    .lineLimit(1)
                if let notes = milestone.notes.nilIfEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondary)
                Text(targetText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)
                if !milestone.reminders.isEmpty {
                    Spacer()
                    Text("提醒 \(milestone.reminders.count) 项")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(palette.accent)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(isEmphasized ? palette.holidayRed.opacity(0.45) : palette.separator, lineWidth: 1)
                )
        )
    }

    private var isToday: Bool { countdown.primaryText == "今天" }
    private var isEmphasized: Bool { isToday || countdown.isPast }
    private var numberColor: Color {
        countdown.isPast ? palette.makeupGray : palette.holidayRed
    }

    private var categoryColor: Color {
        switch milestone.category {
        case .exam: return palette.holidayRed
        case .project: return palette.solarGreen
        case .travel: return palette.accent
        case .anniversary: return .yellow
        case .custom: return palette.secondary
        }
    }

    private var targetText: String {
        milestone.isAllDay
            ? AppFormatters.fullDate.string(from: milestone.targetDate)
            : AppFormatters.fullDateTime.string(from: milestone.targetDate)
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

private struct AnniversaryCard: View {
    @Environment(\.palette) private var palette

    let occurrence: AnniversaryOccurrence

    private var anniversary: Anniversary { occurrence.anniversary }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(kindIcon)
                    .font(.system(size: 14))
                Text(anniversary.kind.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(palette.accent.opacity(0.12)))
                Spacer()
                if let countText = occurrence.countText {
                    Text(countText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(palette.holidayRed)
                }
            }

            Text(cardTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(palette.ink)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 4) {
                Text(dateSpecText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondary)
                Text("下一次 \(nextDateText)")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
                if let fallback = occurrence.fallbackNote {
                    Text(fallback)
                        .font(.system(size: 11))
                        .foregroundColor(palette.makeupGray)
                        .lineLimit(2)
                }
            }

            if !anniversary.reminders.isEmpty {
                Text("提醒 \(anniversary.reminders.count) 项")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(palette.accent)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(palette.card)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(palette.separator, lineWidth: 1))
        )
    }

    private var cardTitle: String {
        if let person = anniversary.personName?.nilIfEmpty {
            return "\(person) · \(anniversary.title)"
        }
        return anniversary.title
    }

    private var kindIcon: String {
        switch anniversary.kind {
        case .birthday: return "🎂"
        case .memorial: return "🕯️"
        case .wedding: return "💍"
        case .custom: return "⭐️"
        }
    }

    private var dateSpecText: String {
        switch anniversary.calendar {
        case .solar:
            return "阳历 \(solarSpecText)"
        case .lunar:
            return "农历 \(lunarSpecText)"
        }
    }

    private var solarSpecText: String {
        let components = anniversary.solarDate
        return "\(components?.year ?? 0)年\(components?.month ?? 0)月\(components?.day ?? 0)日"
    }

    private var lunarSpecText: String {
        guard let spec = anniversary.lunarDate else { return "日期暂不可用" }
        let leap = spec.isLeapMonth ? "闰" : ""
        let month = LunarCalendar.monthNames.indices.contains(spec.month)
            ? LunarCalendar.monthNames[spec.month]
            : "\(spec.month)月"
        let day = LunarCalendar.dayNames.indices.contains(spec.day)
            ? LunarCalendar.dayNames[spec.day]
            : "\(spec.day)日"
        return "\(leap)\(month)\(day)"
    }

    private var nextDateText: String {
        AppFormatters.fullDate.string(from: occurrence.date)
    }
}

struct AnniversaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var milestoneStore: MilestoneStore

    let anniversary: Anniversary?

    @State private var title = ""
    @State private var personName = ""
    @State private var kind: AnniversaryKind = .birthday
    @State private var calendarType: AnniversaryCalendar = .solar
    @State private var solarDate = Date()
    @State private var lunarMonth = 1
    @State private var lunarDay = 1
    @State private var isLeapMonth = false
    @State private var fallback: LeapMonthFallback = .previousCommonMonth
    @State private var originalYearText = ""
    @State private var showAge = true
    @State private var showAnniversaryYears = true
    @State private var notes = ""
    @State private var reminders: [MilestoneReminder] = []
    @State private var deleteConfirmationIsPresented = false

    private let calendar = Calendar.current

    init(anniversary: Anniversary?) {
        self.anniversary = anniversary

        if let anniversary {
            _title = State(initialValue: anniversary.title)
            _personName = State(initialValue: anniversary.personName ?? "")
            _kind = State(initialValue: anniversary.kind)
            _calendarType = State(initialValue: anniversary.calendar)
            _isLeapMonth = State(initialValue: anniversary.lunarDate?.isLeapMonth ?? false)
            _lunarMonth = State(initialValue: anniversary.lunarDate?.month ?? 1)
            _lunarDay = State(initialValue: anniversary.lunarDate?.day ?? 1)
            _fallback = State(initialValue: anniversary.leapMonthFallback)
            _originalYearText = State(
                initialValue: anniversary.lunarDate?.originalYear.map(String.init) ?? ""
            )
            _showAge = State(initialValue: anniversary.showAge)
            _showAnniversaryYears = State(initialValue: anniversary.showAnniversaryYears)
            _notes = State(initialValue: anniversary.notes)
            _reminders = State(initialValue: anniversary.reminders)
            if let components = anniversary.solarDate,
               let date = Calendar.current.date(from: components) {
                _solarDate = State(initialValue: date)
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    TextField("对象（可选）", text: $personName)
                    Picker("类型", selection: $kind) {
                        ForEach(AnniversaryKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    Picker("日期类型", selection: $calendarType) {
                        ForEach(AnniversaryCalendar.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                }

                Section(calendarType == .solar ? "阳历日期" : "农历日期") {
                    if calendarType == .solar {
                        DatePicker("日期", selection: $solarDate, displayedComponents: [.date])
                    } else {
                        Picker("月", selection: $lunarMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(LunarCalendar.monthNames[month]).tag(month)
                            }
                        }
                        Picker("日", selection: $lunarDay) {
                            ForEach(1...30, id: \.self) { day in
                                Text(LunarCalendar.dayNames[day]).tag(day)
                            }
                        }
                        Toggle("闰月", isOn: $isLeapMonth)
                        if isLeapMonth {
                            Picker("闰月缺失", selection: $fallback) {
                                ForEach(LeapMonthFallback.allCases) { item in
                                    Text(item.title).tag(item)
                                }
                            }
                        }
                        TextField("原始年份（用于年龄 / 周年，可选）", text: $originalYearText)
                            .keyboardType(.numberPad)
                    }
                }

                Section("展示") {
                    if kind == .birthday {
                        Toggle("显示年龄", isOn: $showAge)
                    } else {
                        Toggle("显示周年", isOn: $showAnniversaryYears)
                    }
                }

                Section("备注") {
                    TextField("备注（可选）", text: $notes)
                }

                Section("提醒") {
                    ForEach([
                        MilestoneReminderKind.sevenDaysAtNine,
                        .oneDayAtNine,
                        .sameDayAtNine,
                    ], id: \.self) { kind in
                        Toggle(kind.title, isOn: reminderBinding(for: kind))
                    }

                    switch milestoneStore.notificationAuthorization {
                    case .granted:
                        Text("通知已授权，将按计划响铃。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                    case .notDetermined:
                        Text(hasEnabledReminders ? "保存后会请求通知权限。" : "启用提醒后，保存时会请求通知权限。")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondary)
                    case .denied:
                        Text("通知未授权；设置会保存，但不会响铃。")
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
                            Text(anniversary == nil ? "保存生日 / 纪念日" : "保存修改")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)

                    if anniversary != nil {
                        Button(role: .destructive) {
                            deleteConfirmationIsPresented = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除")
                                Spacer()
                            }
                        }
                    }
                } footer: {
                    Text("生日 / 纪念日保存在本机，不写入系统日历或云端。")
                }
            }
            .navigationTitle(anniversary == nil ? "新建纪念日" : "编辑纪念日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("删除这条生日 / 纪念日？", isPresented: $deleteConfirmationIsPresented) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let anniversary {
                        Task {
                            await milestoneStore.remove(anniversary)
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
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasValidYear = originalYearText.trimmingCharacters(in: .whitespaces).isEmpty
            || Int(originalYearText) != nil
        return hasTitle && hasValidYear
    }

    private var hasEnabledReminders: Bool {
        reminders.contains { $0.isEnabled }
    }

    private func save() {
        let updated = Anniversary(
            id: anniversary?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            personName: personName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            kind: kind,
            calendar: calendarType,
            solarDate: solarComponents,
            lunarDate: lunarDateSpec,
            leapMonthFallback: fallback,
            showAge: showAge,
            showAnniversaryYears: showAnniversaryYears,
            reminders: reminders,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: anniversary?.createdAt ?? Date(),
            resolvedDate: anniversary?.resolvedDate,
            resolvedWithFallback: anniversary?.resolvedWithFallback
        )

        Task {
            await milestoneStore.save(updated)
            dismiss()
        }
    }

    private var solarComponents: DateComponents? {
        calendarType == .solar
            ? calendar.dateComponents([.year, .month, .day], from: solarDate)
            : nil
    }

    private var lunarDateSpec: LunarDateSpec? {
        guard calendarType == .lunar else { return nil }
        return LunarDateSpec(
            originalYear: Int(originalYearText.trimmingCharacters(in: .whitespaces)),
            month: lunarMonth,
            day: lunarDay,
            isLeapMonth: isLeapMonth
        )
    }

    private func reminderBinding(for kind: MilestoneReminderKind) -> Binding<Bool> {
        Binding<Bool>(
            get: { reminders.first { $0.kind == kind }?.isEnabled ?? false },
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
