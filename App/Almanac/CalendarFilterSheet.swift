import SwiftUI

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
                    Text("隐藏的日历不会出现在月视图和日详情中。至少保留一个可见日历。")
                }

                ForEach(sourceGroups, id: \.sourceTitle) { group in
                    Section(group.sourceTitle) {
                        ForEach(group.calendars) { calendar in
                            CalendarToggleRow(calendar: calendar)
                        }
                    }
                }
            }
            .navigationTitle("日历筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct CalendarToggleRow: View {
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    let calendar: CalendarDisplayInfo

    var body: some View {
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
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { eventService.isCalendarVisible(calendar.id) },
            set: { eventService.setCalendarVisible(calendar.id, isVisible: $0) }
        )
    }

    private var isToggleDisabled: Bool {
        eventService.isCalendarVisible(calendar.id) && eventService.visibleCalendarCount <= 1
    }

    private var statusText: String {
        var labels: [String] = []
        labels.append(calendar.allowsContentModifications ? "可写" : "只读")
        if calendar.isSubscribed {
            labels.append("订阅")
        }
        return labels.joined(separator: " · ")
    }
}
