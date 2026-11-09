import SwiftUI
import EventSearchKit

struct EventSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @EnvironmentObject private var eventService: EventStoreService

    @State private var searchQuery = EventSearchQuery(keyword: "")
    @State private var selectedEvent: CalendarEvent?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchGeneration = 0
    @State private var recentSearches: [RecentSearchItem] = []
    @State private var recentSearchStore = RecentSearchStore()
    @State private var isCalendarFilterPresented = false
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    private let availableRanges: [EventSearchRange] = [
        .past180ToFuture365Days,
        .next7Days,
        .next30Days,
        .pastAndNext90Days,
        .custom(start: Date(), end: Date().addingTimeInterval(7 * 24 * 60 * 60))
    ]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                searchField
                filterBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        searchStatus
                        searchContent
                    }
                    .padding(.horizontal, 20)
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
        .sheet(isPresented: $isCalendarFilterPresented) {
            calendarFilterSheet
        }
        .onAppear {
            recentSearches = recentSearchStore.load()
        }
        .onChange(of: searchQuery) { newQuery in
            scheduleSearch(newQuery)
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

            TextField("标题 / 地点 / 备注", text: keywordBinding)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit {
                    saveRecentSearch(searchQuery)
                }

            if !searchQuery.keyword.isEmpty {
                Button {
                    searchQuery.keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(palette.secondary)
                }
                .accessibilityLabel("清空搜索关键词")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.card))
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var keywordBinding: Binding<String> {
        Binding(
            get: { searchQuery.keyword },
            set: { searchQuery.keyword = $0 }
        )
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableRanges, id: \.self) { range in
                        Button {
                            selectRange(range)
                        } label: {
                            Text(range.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isRangeSelected(range) ? palette.card : palette.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(
                                        isRangeSelected(range) ? palette.accent : palette.card
                                    )
                                )
                        }
                        .accessibilityLabel("搜索范围 \(range.title)")
                    }

                    Button {
                        isCalendarFilterPresented = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                            Text(calendarFilterTitle)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(searchQuery.calendarIDs == nil ? palette.secondary : palette.card)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                searchQuery.calendarIDs == nil ? palette.card : palette.accent
                            )
                        )
                    }
                    .accessibilityLabel("筛选搜索日历")
                }
                .padding(.horizontal, 20)
            }

            if searchQuery.range.isCustom {
                HStack(spacing: 12) {
                    DatePicker(
                        "开始",
                        selection: customStartBinding,
                        in: ...customEndDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "结束",
                        selection: customEndBinding,
                        in: customStartDate...,
                        displayedComponents: .date
                    )
                }
                .font(.system(size: 12))
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 10)
    }

    private var customStartBinding: Binding<Date> {
        Binding(
            get: { customStartDate },
            set: { newValue in
                customStartDate = newValue
                if customEndDate < customStartDate {
                    customEndDate = customStartDate
                }
                searchQuery.range = .custom(start: customStartDate, end: customEndDate)
            }
        )
    }

    private var customEndBinding: Binding<Date> {
        Binding(
            get: { customEndDate },
            set: { newValue in
                customEndDate = newValue
                if customStartDate > customEndDate {
                    customStartDate = customEndDate
                }
                searchQuery.range = .custom(start: customStartDate, end: customEndDate)
            }
        )
    }

    @ViewBuilder
    private var searchStatus: some View {
        if eventService.searchRangeWasCapped {
            notice("搜索范围过大，已自动限制为 730 天")
        }
        if eventService.searchResultLimitReached {
            notice("仅显示前 200 条，请缩小范围或换更具体的关键词")
        }
        if eventService.isSearching {
            HStack(spacing: 8) {
                ProgressView()
                Text("搜索中")
                    .font(.system(size: 12))
                    .foregroundColor(palette.secondary)
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if searchQuery.keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if recentSearches.isEmpty {
                emptyView(
                    title: "输入关键词开始搜索",
                    message: "可搜索标题、地点和备注；也可以从最近搜索继续。"
                )
            } else {
                recentSearchList
            }
        } else if let error = eventService.searchErrorMessage {
            VStack(spacing: 12) {
                emptyView(title: "搜索失败", message: error)
                Button("授权系统日历") {
                    Task {
                        await eventService.requestAccessIfNeeded()
                        scheduleSearch(searchQuery)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(palette.accent)
            }
        } else if eventService.searchResults.isEmpty && !eventService.isSearching {
            emptyView(
                title: "没有匹配日程",
                message: "换个关键词、扩大搜索范围，或检查日历筛选后再试。"
            )
        } else if !eventService.searchResults.isEmpty {
            LazyVStack(spacing: 8) {
                ForEach(eventService.searchResults) { event in
                    SearchResultRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEvent = event
                        }
                }
            }
            .padding(.top, 4)
        }
    }

    private var recentSearchList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近搜索")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(palette.secondary)
                .padding(.top, 4)

            LazyVStack(spacing: 8) {
                ForEach(recentSearches) { item in
                    HStack(spacing: 10) {
                        Button {
                            selectRecentSearch(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.keyword)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(palette.ink)
                                Text(item.range.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(palette.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            recentSearchStore.remove(item)
                            recentSearches = recentSearchStore.load()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(palette.secondary)
                        }
                        .accessibilityLabel("删除最近搜索 \(item.keyword)")
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(palette.card))
                }
            }
        }
    }

    private var calendarFilterSheet: some View {
        NavigationView {
            List {
                Section {
                    Button("全部日历") {
                        searchQuery.calendarIDs = nil
                    }
                    .foregroundColor(searchQuery.calendarIDs == nil ? palette.accent : palette.ink)
                }

                Section("搜索的日历") {
                    ForEach(visibleCalendars) { calendar in
                        Toggle(isOn: calendarBinding(calendar)) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(calendar.color.swiftUIColor)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(calendar.title)
                                    Text(calendar.sourceTitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(palette.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("日历筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        isCalendarFilterPresented = false
                    }
                }
            }
        }
    }

    private var visibleCalendars: [CalendarDisplayInfo] {
        eventService.calendars.filter { eventService.isCalendarVisible($0.id) }
    }

    private var calendarFilterTitle: String {
        guard let calendarIDs = searchQuery.calendarIDs else { return "全部日历" }
        if calendarIDs.count == 1,
           let calendar = eventService.calendars.first(where: { $0.id == calendarIDs.first }) {
            return calendar.title
        }
        return "\(calendarIDs.count) 个日历"
    }

    private func calendarBinding(_ calendar: CalendarDisplayInfo) -> Binding<Bool> {
        Binding(
            get: {
                searchQuery.calendarIDs?.contains(calendar.id) ?? false
            },
            set: { isSelected in
                var selectedIDs = searchQuery.calendarIDs ?? Set(visibleCalendars.map(\.id))
                if isSelected {
                    selectedIDs.insert(calendar.id)
                } else {
                    selectedIDs.remove(calendar.id)
                }
                searchQuery.calendarIDs = selectedIDs.isEmpty ? nil : selectedIDs
            }
        )
    }

    private func isRangeSelected(_ range: EventSearchRange) -> Bool {
        if range.isCustom {
            return searchQuery.range.isCustom
        }
        return searchQuery.range == range
    }

    private func selectRange(_ range: EventSearchRange) {
        if case .custom = range {
            searchQuery.range = .custom(start: customStartDate, end: customEndDate)
        } else {
            searchQuery.range = range
        }
    }

    private func selectRecentSearch(_ item: RecentSearchItem) {
        searchQuery.keyword = item.keyword
        searchQuery.range = item.range
        saveRecentSearch(searchQuery)
    }

    private func saveRecentSearch(_ query: EventSearchQuery) {
        guard query.canSearch else { return }
        recentSearchStore.save(keyword: query.keyword, range: query.range)
        recentSearches = recentSearchStore.load()
    }

    private func scheduleSearch(_ query: EventSearchQuery) {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration

        guard query.canSearch else {
            eventService.clearSearchResults()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, generation == searchGeneration else { return }
            await eventService.searchEvents(query: query)
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(palette.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(palette.card))
            .padding(.top, 4)
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
        .padding(.horizontal, 4)
        .padding(.top, 32)
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
                if event.hasRecurrenceRules {
                    Text(event.recurrenceSummary ?? "重复")
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondary)
                }
                if event.reminderOption != .none {
                    Text(event.reminderSummary)
                        .font(.system(size: 10))
                        .foregroundColor(palette.secondary)
                }
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
        if event.isAllDay {
            return "\(AppFormatters.fullDate.string(from: event.startDate)) · 全天"
        }

        let sameDay = Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate)
        if sameDay {
            return "\(AppFormatters.fullDate.string(from: event.startDate)) \(AppFormatters.hhmm.string(from: event.startDate)) – \(AppFormatters.hhmm.string(from: event.endDate))"
        }

        return "\(AppFormatters.fullDateTime.string(from: event.startDate)) – \(AppFormatters.fullDateTime.string(from: event.endDate))"
    }
}
