import SwiftUI

/// 日程详情。可写事件从这里进入编辑，删除也在这里显式确认。
struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    let event: CalendarEvent
    let onDeleted: () -> Void

    @State private var editContext: EditEventContext?
    @State private var isDeleteConfirmationPresented = false
    @State private var errorMessage: String?
    @State private var isDeleting = false

    private var currentEvent: CalendarEvent {
        eventService.events.first { $0.id == event.id } ?? event
    }

    var body: some View {
        NavigationView {
            Form {
                Section("日程") {
                    detailRow("标题", currentEvent.title)
                    detailRow("时间", timeText)
                    detailRow("全天", currentEvent.isAllDay ? "是" : "否")
                    if let location = currentEvent.location, !location.isEmpty {
                        detailRow("地点", location)
                    }
                    if let notes = currentEvent.notes, !notes.isEmpty {
                        detailRow("备注", notes)
                    }
                }

                Section("日历") {
                    detailRow("日历", currentEvent.calendarTitle)
                    detailRow("写入权限", currentEvent.isWritable ? "可编辑" : "只读")
                    if currentEvent.hasRecurrenceRules {
                        detailRow("重复日程", "v1 只能修改或删除当前这一次")
                    }
                }

                Section {
                    if currentEvent.isWritable {
                        Button {
                            editContext = EditEventContext(event: currentEvent)
                        } label: {
                            Label("编辑日程", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            isDeleteConfirmationPresented = true
                        } label: {
                            if isDeleting {
                                ProgressView()
                            } else {
                                Label("删除日程", systemImage: "trash")
                            }
                        }
                        .disabled(isDeleting)
                    } else {
                        Text("该日历只读，宜历暂不能修改这条日程。")
                            .font(.footnote)
                            .foregroundColor(palette.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(palette.holidayRed)
                    }
                } footer: {
                    Text("日程来自系统日历。修改会通过 EventKit 写回原始日历。")
                }
            }
            .navigationTitle("日程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $editContext) { context in
                EventEditView(event: context.event)
            }
            .alert("删除这条日程？", isPresented: $isDeleteConfirmationPresented) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    delete()
                }
            } message: {
                Text("该操作会从系统日历中删除这条日程，且不能在宜历内撤销。")
            }
            .onChange(of: eventService.events) { events in
                // 事件被移出当前加载区间或被删除时，关闭已过期的详情。
                if !events.contains(where: { $0.id == event.id }) {
                    dismiss()
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(palette.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(palette.ink)
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if currentEvent.isAllDay {
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: currentEvent.startDate)
        }

        let sameDay = Calendar.current.isDate(currentEvent.startDate, inSameDayAs: currentEvent.endDate)
        if sameDay {
            formatter.dateFormat = "yyyy年M月d日 HH:mm – HH:mm"
            return formatter.string(from: currentEvent.startDate)
        }

        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return "\(formatter.string(from: currentEvent.startDate)) – \(formatter.string(from: currentEvent.endDate))"
    }

    private func delete() {
        errorMessage = nil
        isDeleting = true

        Task {
            do {
                try await eventService.deleteEvent(currentEvent)
                isDeleting = false
                onDeleted()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}

struct EditEventContext: Identifiable {
    let id = UUID()
    let event: CalendarEvent
}

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    let event: CalendarEvent

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var selectedCalendarID: String?
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let calendar = Calendar.current

    init(event: CalendarEvent) {
        self.event = event
        _title = State(initialValue: event.title)
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: max(event.endDate, event.startDate))
        _isAllDay = State(initialValue: event.isAllDay)
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _selectedCalendarID = State(initialValue: event.calendarIdentifier)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    Toggle("全天", isOn: $isAllDay)

                    if isAllDay {
                        DatePicker(
                            "日期",
                            selection: $startDate,
                            displayedComponents: [.date]
                        )
                        .onChange(of: startDate) { newValue in
                            endDate = calendar.date(
                                byAdding: .day,
                                value: 1,
                                to: calendar.startOfDay(for: newValue)
                            ) ?? newValue
                        }
                    } else {
                        DatePicker(
                            "开始",
                            selection: $startDate,
                            displayedComponents: [.hourAndMinute]
                        )
                        .onChange(of: startDate) { newValue in
                            if endDate <= newValue {
                                endDate = calendar.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                            }
                        }
                        DatePicker(
                            "结束",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                }

                Section("详情") {
                    TextField("地点（可选）", text: $location)
                    TextField("备注（可选）", text: $notes)
                }

                Section("日历") {
                    if eventService.writableCalendars.isEmpty {
                        Text("没有可写入日历")
                            .foregroundColor(palette.secondary)
                    } else {
                        Picker("保存到", selection: $selectedCalendarID) {
                            ForEach(eventService.writableCalendars) { item in
                                Text("\(item.title) · \(item.sourceTitle)")
                                    .tag(Optional(item.id))
                            }
                        }
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("保存修改")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSave || isSaving)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(palette.holidayRed)
                    }
                } footer: {
                    if event.hasRecurrenceRules {
                        Text("这是重复日程。v1 只会修改当前这一次，不会影响其他日期。")
                    } else {
                        Text("修改会保存到系统日历。")
                    }
                }
            }
            .navigationTitle("编辑日程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                eventService.loadWritableCalendars()
                selectedCalendarID = eventService.selectedWritableCalendarID(fallback: selectedCalendarID)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (isAllDay || endDate > startDate)
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        let calendarID = selectedCalendarID

        Task {
            do {
                try await eventService.updateEvent(
                    event,
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    location: location,
                    notes: notes,
                    calendarIdentifier: calendarID
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
