import SwiftUI

/// 新建系统日历事件。v1 只保留 MVP 必填字段。
struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay = false
    @State private var location = ""
    @State private var notes = ""
    @State private var reminderOption: EventReminderOption = .none
    @State private var recurrenceDraft: EventRecurrenceDraft
    @State private var selectedCalendarID: String?
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let calendar = Calendar.current

    init(initialDate: Date) {
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate)
            ?? Calendar.current.startOfDay(for: initialDate)
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
        _recurrenceDraft = State(initialValue: EventRecurrenceDraft(startDate: start))
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

                Section("重复") {
                    EventRecurrenceEditor(
                        draft: $recurrenceDraft,
                        startDate: startDate,
                        isProtected: false
                    )
                }

                Section("提醒") {
                    Picker("提醒", selection: $reminderOption) {
                        ForEach(EventReminderOption.standardOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
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
                                Text("保存日程")
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
                    Text("日程会保存到系统日历，并按 EventKit 作为唯一数据源同步展示。")
                }
            }
            .navigationTitle("新建日程")
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
                try await eventService.saveEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    location: location,
                    notes: notes,
                    calendarIdentifier: calendarID,
                    reminderOption: reminderOption,
                    recurrenceDraft: recurrenceDraft
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
