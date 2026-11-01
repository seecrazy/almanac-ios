import SwiftUI

struct EventSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @State private var query = ""
    @State private var selectedEvent: CalendarEvent?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchGeneration = 0

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                searchField

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if eventService.isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.top, 48)
                        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            emptyView(
                                title: "输入关键词开始搜索",
                                message: "可搜索标题、地点和备注。搜索范围为过去 180 天至未来 365 天。"
                            )
                        } else if let error = eventService.searchErrorMessage {
                            emptyView(title: "搜索失败", message: error)
                        } else if eventService.searchResults.isEmpty {
                            emptyView(
                                title: "没有匹配日程",
                                message: "换个关键词，或扩大搜索范围后再试。"
                            )
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(eventService.searchResults) { event in
                                    SearchResultRow(event: event)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedEvent = event
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("搜索日程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event) {}
        }
        .onChange(of: query) { newValue in
            scheduleSearch(query: newValue)
        }
        .onDisappear {
            searchTask?.cancel()
            eventService.clearSearchResults()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(palette.secondary)

            TextField("标题 / 地点 / 备注", text: $query)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(palette.secondary)
                }
                .accessibilityLabel("清空搜索关键词")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.card))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func emptyView(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(palette.ink)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 48)
    }

    private func scheduleSearch(query newValue: String) {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration

        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            eventService.clearSearchResults()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, generation == searchGeneration else { return }

            let calendar = Calendar.current
            let now = Date()
            let start = calendar.date(byAdding: .day, value: -180, to: now) ?? now
            let end = calendar.date(byAdding: .day, value: 365, to: now) ?? now
            await eventService.searchEvents(query: newValue, from: start, to: end)
        }
    }
}

private struct SearchResultRow: View {
    @Environment(\.palette) private var palette

    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor?.swiftUIColor ?? palette.accent)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.ink)
                Text(dateText)
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondary)
                }
                Text(event.calendarTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(palette.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(palette.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.card))
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if event.isAllDay {
            formatter.dateFormat = "yyyy年M月d日"
            return "\(formatter.string(from: event.startDate)) · 全天"
        }

        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        let sameDay = Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate)
        if sameDay {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return "\(formatter.string(from: event.startDate)) – \(timeFormatter.string(from: event.endDate))"
        }

        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }
}
