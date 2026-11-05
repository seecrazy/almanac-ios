import SwiftUI
import EventKitMapping

extension CalendarColorComponents {
    var swiftUIColor: Color {
        Color(
            red: red,
            green: green,
            blue: blue,
            opacity: opacity
        )
    }
}

struct CalendarFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @State private var isShowingCreateSheet = false
    @State private var calendarBeingRenamed: CalendarDisplayInfo?
    @State private var calendarPendingDeletion: CalendarDisplayInfo?
    @State private var actionErrorMessage: String?
    @State private var isPerformingAction = false

    private var sourceGroups: [(sourceTitle: String, calendars: [CalendarDisplayInfo])] {
        Dictionary(grouping: eventService.calendars, by: \.sourceTitle)
            .map { (sourceTitle: $0.key, calendars: $0.value) }
            .sorted { $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        eventService.showAllCalendars()
                    } label: {
                        Label("全部显示", systemImage: "eye")
                    }
                    .disabled(eventService.visibleCalendarCount == eventService.calendars.count)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("隐藏的日历不会出现在月视图和日详情中。至少保留一个可见日历。")
                        if eventService.accessState == .granted {
                            Text("仅本机可写日历支持重命名和删除；远端与订阅日历保持系统管理。")
                        }
                        if let actionErrorMessage {
                            Text(actionErrorMessage)
                                .foregroundColor(palette.holidayRed)
                        }
                    }
                }

                ForEach(sourceGroups, id: \.sourceTitle) { group in
                    Section(group.sourceTitle) {
                        ForEach(group.calendars) { calendar in
                            CalendarToggleRow(
                                calendar: calendar,
                                onRename: {
                                    actionErrorMessage = nil
                                    calendarBeingRenamed = calendar
                                },
                                onRequestDeletion: {
                                    actionErrorMessage = nil
                                    calendarPendingDeletion = calendar
                                },
                                isActionDisabled: isPerformingAction
                            )
                        }
                    }
                }
            }
            .navigationTitle("日历筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if eventService.accessState == .granted {
                        Button {
                            actionErrorMessage = nil
                            isShowingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(isPerformingAction)
                        .accessibilityLabel("新建本机日历")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .disabled(isPerformingAction)
                }
            }
            .sheet(isPresented: $isShowingCreateSheet) {
                CalendarNameSheet(mode: .create) { title in
                    try await createCalendar(title)
                }
            }
            .sheet(item: $calendarBeingRenamed) { calendar in
                CalendarNameSheet(mode: .rename(calendar.title)) { title in
                    try await renameCalendar(calendar, title: title)
                }
            }
            .confirmationDialog(
                "删除日历",
                isPresented: Binding(
                    get: { calendarPendingDeletion != nil },
                    set: { if !$0 { calendarPendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除该日历及日程", role: .destructive) {
                    if let calendar = calendarPendingDeletion {
                        Task { await deleteCalendar(calendar) }
                    }
                }
                Button("取消", role: .cancel) {
                    calendarPendingDeletion = nil
                }
            } message: {
                if let calendar = calendarPendingDeletion {
                    Text("将删除“\(calendar.title)”及其所有日程。该操作在宜历内不能撤销。")
                }
            }
        }
    }

    private func createCalendar(_ title: String) async throws {
        isPerformingAction = true
        actionErrorMessage = nil
        defer { isPerformingAction = false }

        do {
            try await eventService.createLocalCalendar(title: title)
        } catch {
            actionErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func renameCalendar(_ calendar: CalendarDisplayInfo, title: String) async throws {
        isPerformingAction = true
        actionErrorMessage = nil
        defer { isPerformingAction = false }

        do {
            try await eventService.renameCalendar(id: calendar.id, title: title)
        } catch {
            actionErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func deleteCalendar(_ calendar: CalendarDisplayInfo) async {
        isPerformingAction = true
        actionErrorMessage = nil
        defer {
            isPerformingAction = false
            calendarPendingDeletion = nil
        }

        do {
            try await eventService.deleteCalendar(id: calendar.id)
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
}

private struct CalendarToggleRow: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    let calendar: CalendarDisplayInfo

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: binding) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(calendar.color.swiftUIColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(calendar.title)
                            .foregroundColor(palette.ink)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(palette.secondary)
                    }
                }
            }
            .disabled(isToggleDisabled)

            if isManageable {
                Menu {
                    Button("重命名") {
                        onRename()
                    }
                    Button("删除日历", role: .destructive) {
                        onRequestDeletion()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .disabled(isActionDisabled)
                .accessibilityLabel("管理\(calendar.title)")
            }
        }
    }

    let onRename: () -> Void
    let onRequestDeletion: () -> Void
    let isActionDisabled: Bool

    private var binding: Binding<Bool> {
        Binding(
            get: { eventService.isCalendarVisible(calendar.id) },
            set: { eventService.setCalendarVisible(calendar.id, isVisible: $0) }
        )
    }

    private var isToggleDisabled: Bool {
        eventService.isCalendarVisible(calendar.id) && eventService.visibleCalendarCount <= 1
    }

    private var isManageable: Bool {
        CalendarManagementPolicy.canManageCalendar(
            isLocal: calendar.isLocal,
            allowsContentModifications: calendar.allowsContentModifications
        )
    }

    private var statusText: String {
        var labels: [String] = []
        labels.append(calendar.allowsContentModifications ? "可写" : "只读")
        if calendar.isLocal {
            labels.append("本机")
        }
        if calendar.isSubscribed {
            labels.append("订阅")
        }
        return labels.joined(separator: " · ")
    }
}

private struct CalendarNameSheet: View {
    enum Mode {
        case create
        case rename(String)

        var title: String {
            switch self {
            case .create: return "新建本机日历"
            case .rename: return "重命名日历"
            }
        }

        var initialText: String {
            switch self {
            case .create: return ""
            case .rename(let title): return title
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private let mode: Mode
    private let save: (String) async throws -> Void

    @State private var title: String
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var isTitleFocused: Bool

    init(mode: Mode, save: @escaping (String) async throws -> Void) {
        self.mode = mode
        self.save = save
        _title = State(initialValue: mode.initialText)
    }

    private var validationError: CalendarNameValidationError? {
        if case .failure(let error) = CalendarManagementPolicy.normalizedTitle(title) {
            return error
        }
        return nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("日历名称", text: $title)
                        .focused($isTitleFocused)
                        .onSubmit(saveIfValid)
                    HStack {
                        Text("\(title.count)/\(CalendarManagementPolicy.maximumNameLength)")
                        Spacer()
                        if let validationError {
                            Text(validationMessage(validationError))
                                .foregroundColor(palette.holidayRed)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(palette.secondary)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("新日历会创建到本机 EventKit 来源，并默认显示。")
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(palette.holidayRed)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中" : "保存", action: saveIfValid)
                        .disabled(validationError != nil || isSaving)
                }
            }
            .onAppear { isTitleFocused = true }
        }
    }

    private func saveIfValid() {
        guard validationError == nil, !isSaving else { return }
        errorMessage = nil
        isSaving = true

        Task {
            do {
                try await save(title)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func validationMessage(_ error: CalendarNameValidationError) -> String {
        switch error {
        case .empty: return "请输入名称"
        case .tooLong: return "最多 \(CalendarManagementPolicy.maximumNameLength) 个字符"
        }
    }
}
