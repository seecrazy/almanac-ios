import EventKit
import EventKitMapping
import EventSearchKit
import Foundation
import CoreGraphics
import CalendarAnalysis

/// App 内使用的轻量日程模型，避免 EventKit 类型穿透 UI。
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let eventIdentifier: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarIdentifier: String?
    let calendarTitle: String
    let calendarColor: CalendarColorComponents?
    let isWritable: Bool
    let hasRecurrenceRules: Bool
    let reminderOption: EventReminderOption
    let reminderSummary: String
    let hasUnsupportedAlarms: Bool
    let recurrenceSummary: String?
    let recurrenceDraft: EventRecurrenceDraft?

    init(from event: EKEvent) {
        let baseIdentifier = event.eventIdentifier ?? event.calendarItemExternalIdentifier ?? ""
        let occurrenceID = [
            baseIdentifier,
            String(event.startDate.timeIntervalSince1970),
            String(event.endDate.timeIntervalSince1970)
        ].joined(separator: "|")

        self.id = occurrenceID
        self.eventIdentifier = event.eventIdentifier ?? event.calendarItemExternalIdentifier
        self.title = event.title?.isEmpty == false ? event.title! : "无标题日程"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.location = event.location
        self.notes = event.notes
        self.calendarIdentifier = event.calendar?.calendarIdentifier
        self.calendarTitle = event.calendar?.title ?? "日历"
        self.calendarColor = CalendarColorComponents(cgColor: event.calendar?.cgColor)
        self.isWritable = event.calendar?.allowsContentModifications == true
        self.hasRecurrenceRules = !(event.recurrenceRules?.isEmpty ?? true)
        self.recurrenceDraft = EventRecurrenceDraft(rules: event.recurrenceRules, startDate: event.startDate)
        self.recurrenceSummary = EventRecurrenceDraft.summary(for: event.recurrenceRules, startDate: event.startDate)
        self.reminderOption = EventReminderOption(from: event.alarms ?? [])
        self.reminderSummary = EventReminderOption.summary(for: event.alarms ?? [])
        self.hasUnsupportedAlarms = EventReminderOption(from: event.alarms ?? []) == .preserveExisting
    }
}

struct CalendarColorComponents: Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init?(cgColor: CGColor?) {
        guard let cgColor,
              let sRGBSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(
                to: sRGBSpace,
                intent: .relativeColorimetric,
                options: nil
              ),
              let components = converted.components,
              !components.isEmpty else {
            return nil
        }

        if components.count >= 3 {
            red = Double(components[0])
            green = Double(components[1])
            blue = Double(components[2])
            opacity = components.count >= 4 ? Double(components[3]) : 1
        } else if components.count == 1 {
            let gray = Double(components[0])
            red = gray
            green = gray
            blue = gray
            opacity = 1
        } else {
            return nil
        }
    }

    static let fallback = CalendarColorComponents(
        red: 0.710,
        green: 0.537,
        blue: 0.235,
        opacity: 1
    )

    init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
}

extension CalendarEvent {
    var analysisEvent: AnalysisEvent {
        AnalysisEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
    }
}

struct CalendarDisplayInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
    let color: CalendarColorComponents
    let allowsContentModifications: Bool
    let isSubscribed: Bool
    let isLocal: Bool
}

/// v1 只管理一条相对提醒；无法归一化的系统提醒保持只读保护。
enum EventReminderOption: Hashable, CaseIterable, Identifiable {
    case none
    case atStart
    case minutesBefore(Int)
    case preserveExisting

    static let standardOptions: [EventReminderOption] = [
        .none,
        .atStart,
        .minutesBefore(5),
        .minutesBefore(15),
        .minutesBefore(30),
        .minutesBefore(60),
        .minutesBefore(24 * 60)
    ]

    static var allCases: [EventReminderOption] {
        standardOptions + [.preserveExisting]
    }

    var id: String {
        switch self {
        case .none: return "none"
        case .atStart: return "at-start"
        case .preserveExisting: return "preserve-existing"
        case .minutesBefore(let minutes): return "minutes-\(minutes)"
        }
    }

    var title: String {
        switch self {
        case .none:
            return "不提醒"
        case .atStart:
            return "准时"
        case .preserveExisting:
            return "保留现有提醒"
        case .minutesBefore(let minutes):
            switch minutes {
            case 60: return "提前 1 小时"
            case 24 * 60: return "提前 1 天"
            default: return "提前 \(minutes) 分钟"
            }
        }
    }

    var relativeOffset: TimeInterval? {
        switch self {
        case .none, .preserveExisting:
            return nil
        case .atStart:
            return 0
        case .minutesBefore(let minutes):
            return -Double(minutes * 60)
        }
    }

    init?(relativeOffset offset: TimeInterval) {
        if offset == 0 {
            self = .atStart
            return
        }
        guard offset < 0, offset.truncatingRemainder(dividingBy: 60) == 0 else { return nil }
        self = .minutesBefore(Int(abs(offset) / 60))
    }

    init(from alarms: [EKAlarm]) {
        guard !alarms.isEmpty else {
            self = .none
            return
        }
        let alarm = alarms[0]
        guard alarm.absoluteDate == nil,
              let option = EventReminderOption(relativeOffset: alarm.relativeOffset) else {
            self = .preserveExisting
            return
        }
        self = option
    }

    static func formOptions(hasUnsupportedAlarms: Bool) -> [EventReminderOption] {
        hasUnsupportedAlarms ? allCases : standardOptions
    }

    static func summary(for alarms: [EKAlarm]) -> String {
        switch EventReminderOption(from: alarms) {
        case .none:
            return "不提醒"
        case .preserveExisting:
            return "系统自定义提醒（宜历 v1 不修改）"
        case .atStart, .minutesBefore:
            return EventReminderOption(from: alarms).title
        }
    }
}

/// 新建事件表单里可选择的最小日历信息。
struct WritableCalendar: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
}

enum EventStoreError: LocalizedError {
    case accessDenied
    case invalidDates
    case noWritableCalendar
    case invalidCalendarName(CalendarNameValidationError)
    case noLocalCalendarSource
    case calendarNotFound
    case calendarNotManageable
    case eventNotFound
    case readOnlyEvent
    case saveFailed(String)
    case deleteFailed(String)
    case calendarSaveFailed(String)
    case calendarDeleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "没有系统日历写入权限"
        case .invalidDates:
            return "结束时间必须晚于开始时间"
        case .noWritableCalendar:
            return "没有可写入的日历"
        case .invalidCalendarName(let reason):
            switch reason {
            case .empty: return "请输入日历名称"
            case .tooLong: return "日历名称不能超过 \(CalendarManagementPolicy.maximumNameLength) 个字符"
            }
        case .noLocalCalendarSource:
            return "没有可用的本机日历来源"
        case .calendarNotFound:
            return "日历不存在或已被删除"
        case .calendarNotManageable:
            return "仅支持管理本机可写日历"
        case .eventNotFound:
            return "日程不存在或已被删除"
        case .readOnlyEvent:
            return "该日历只读，不能修改或删除"
        case .saveFailed(let message):
            return message
        case .deleteFailed(let message):
            return message
        case .calendarSaveFailed(let message):
            return message
        case .calendarDeleteFailed(let message):
            return message
        }
    }
}

/// EventKit 是日程数据的唯一源头（ADR-001）。
@MainActor
final class EventStoreService: ObservableObject {
    enum AccessState {
        case notDetermined
        case denied
        case granted
    }

    @Published private(set) var accessState: AccessState = .notDetermined
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var writableCalendars: [WritableCalendar] = []
    @Published private(set) var defaultCalendarIdentifier: String?
    @Published private(set) var calendars: [CalendarDisplayInfo] = []
    @Published private(set) var hiddenCalendarIDs: Set<String>
    @Published private(set) var searchResults: [CalendarEvent] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchErrorMessage: String?
    @Published private(set) var searchRangeWasCapped = false
    @Published private(set) var searchResultLimitReached = false

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private var loadedInterval: DateInterval?
    private let hiddenCalendarIDsKey = "hidden.event.calendar.identifiers"
    private var searchRequestGeneration = 0

    init() {
        let persistedHiddenIDs = UserDefaults.standard.stringArray(forKey: hiddenCalendarIDsKey) ?? []
        _hiddenCalendarIDs = Published(initialValue: Set(persistedHiddenIDs))
        refreshAuthorizationState()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.reloadIfNecessary() }
        }

        Task { [weak self] in
            await MainActor.run {
                self?.loadCalendars()
            }
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func requestAccessIfNeeded() async {
        refreshAuthorizationState()
        guard accessState == .notDetermined else {
            loadCalendars()
            await reloadIfNecessary()
            return
        }

        let granted: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            granted = await withCheckedContinuation { continuation in
                store.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            granted = await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }

        refreshAuthorizationState()
        if granted {
            loadCalendars()
            await reloadIfNecessary()
        } else {
            lastErrorMessage = "未获得日历访问权限"
        }
    }

    func loadEvents(from start: Date, to end: Date, appending: Bool = false) async {
        refreshAuthorizationState()
        guard accessState == .granted else { return }
        let interval = DateInterval(start: start, end: max(start, end))
        if appending, let current = loadedInterval {
            loadedInterval = DateInterval(
                start: min(current.start, interval.start),
                end: max(current.end, interval.end)
            )
        } else {
            loadedInterval = interval
        }

        let fetchedEvents = await Task.detached(priority: .userInitiated) { [store] in
            let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
            return store.events(matching: predicate).map(CalendarEvent.init(from:))
        }.value

        let combinedEvents = appending ? events + fetchedEvents : fetchedEvents
        var seenIDs = Set<String>()
        events = combinedEvents
            .filter { seenIDs.insert($0.id).inserted }
            .filter { isCalendarVisible($0.calendarIdentifier) }
            .sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                if $0.startDate == $1.startDate { return $0.endDate < $1.endDate }
                return $0.startDate < $1.startDate
            }
    }

    func loadWritableCalendars() {
        refreshAuthorizationState()
        guard accessState == .granted else {
            writableCalendars = []
            defaultCalendarIdentifier = nil
            return
        }

        writableCalendars = store.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map { calendar in
                WritableCalendar(
                    id: calendar.calendarIdentifier,
                    title: calendar.title.isEmpty ? "未命名日历" : calendar.title,
                    sourceTitle: calendar.source?.title ?? "本地"
                )
            }
            .sorted { lhs, rhs in
                if lhs.sourceTitle != rhs.sourceTitle { return lhs.sourceTitle < rhs.sourceTitle }
                return lhs.title < rhs.title
            }
        defaultCalendarIdentifier = store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    func loadCalendars() {
        refreshAuthorizationState()
        guard accessState == .granted else {
            calendars = []
            return
        }

        let infos = store.calendars(for: .event)
            .map { calendar in
                CalendarDisplayInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title.isEmpty ? "未命名日历" : calendar.title,
                    sourceTitle: calendar.source?.title ?? "本地",
                    color: CalendarColorComponents(cgColor: calendar.cgColor) ?? .fallback,
                    allowsContentModifications: calendar.allowsContentModifications,
                    isSubscribed: calendar.isSubscribed,
                    isLocal: calendar.source?.sourceType == .local
                )
            }
            .sorted { lhs, rhs in
                if lhs.sourceTitle.caseInsensitiveCompare(rhs.sourceTitle) != .orderedSame {
                    return lhs.sourceTitle.localizedCaseInsensitiveCompare(rhs.sourceTitle) == .orderedAscending
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        calendars = infos
        hiddenCalendarIDs.formIntersection(Set(infos.map(\.id)))
        persistHiddenCalendarIDs()
    }

    var visibleCalendarCount: Int {
        calendars.isEmpty
            ? max(0, 1 - hiddenCalendarIDs.count)
            : max(calendars.count - hiddenCalendarIDs.count, 0)
    }

    func isCalendarVisible(_ identifier: String?) -> Bool {
        guard let identifier else { return true }
        return !hiddenCalendarIDs.contains(identifier)
    }

    func setCalendarVisible(_ identifier: String, isVisible: Bool) {
        if isVisible {
            hiddenCalendarIDs.remove(identifier)
        } else {
            guard isCalendarVisible(identifier), visibleCalendarCount > 1 else { return }
            hiddenCalendarIDs.insert(identifier)
        }
        persistHiddenCalendarIDs()
    }

    func showAllCalendars() {
        hiddenCalendarIDs.removeAll()
        persistHiddenCalendarIDs()
    }

    func createLocalCalendar(title: String) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }

        let normalizedTitle = try CalendarManagementPolicy.normalizedTitle(title).get()
        guard let localSource = store.sources.first(where: { $0.sourceType == .local }) else {
            throw EventStoreError.noLocalCalendarSource
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = normalizedTitle
        calendar.source = localSource

        do {
            try store.saveCalendar(calendar, commit: true)
        } catch {
            throw EventStoreError.calendarSaveFailed(error.localizedDescription)
        }

        await refreshAfterCalendarMetadataChange()
    }

    func renameCalendar(id: String, title: String) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }

        let normalizedTitle = try CalendarManagementPolicy.normalizedTitle(title).get()
        guard let calendar = store.calendar(withIdentifier: id) else {
            throw EventStoreError.calendarNotFound
        }
        guard CalendarManagementPolicy.canManageCalendar(
            isLocal: calendar.source?.sourceType == .local,
            allowsContentModifications: calendar.allowsContentModifications
        ) else {
            throw EventStoreError.calendarNotManageable
        }

        calendar.title = normalizedTitle
        do {
            try store.saveCalendar(calendar, commit: true)
        } catch {
            throw EventStoreError.calendarSaveFailed(error.localizedDescription)
        }

        await refreshAfterCalendarMetadataChange()
    }

    func deleteCalendar(id: String) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }

        guard let calendar = store.calendar(withIdentifier: id) else {
            throw EventStoreError.calendarNotFound
        }
        guard CalendarManagementPolicy.canManageCalendar(
            isLocal: calendar.source?.sourceType == .local,
            allowsContentModifications: calendar.allowsContentModifications
        ) else {
            throw EventStoreError.calendarNotManageable
        }

        do {
            try store.removeCalendar(calendar, commit: true)
        } catch {
            throw EventStoreError.calendarDeleteFailed(error.localizedDescription)
        }

        hiddenCalendarIDs.remove(id)
        persistHiddenCalendarIDs()
        await refreshAfterCalendarMetadataChange()
    }

    func selectedWritableCalendarID(fallback: String?) -> String? {
        let preferredID = fallback ?? defaultCalendarIdentifier
        if let preferredID,
           writableCalendars.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        return writableCalendars.first?.id
    }

    func clearSearchResults() {
        searchRequestGeneration += 1
        searchResults = []
        isSearching = false
        searchErrorMessage = nil
        searchRangeWasCapped = false
        searchResultLimitReached = false
    }

    func searchEvents(query: EventSearchQuery) async {
        refreshAuthorizationState()
        searchRequestGeneration += 1
        let requestGeneration = searchRequestGeneration
        let trimmedQuery = query.trimmedKeyword

        guard accessState == .granted else {
            searchResults = []
            isSearching = false
            searchErrorMessage = "未授权读取系统日历"
            searchRangeWasCapped = false
            searchResultLimitReached = false
            return
        }

        guard query.canSearch else {
            searchResults = []
            isSearching = false
            searchErrorMessage = nil
            searchRangeWasCapped = false
            searchResultLimitReached = false
            return
        }

        isSearching = true
        searchErrorMessage = nil
        let resolvedInterval = query.resolvedInterval(referenceDate: Date(), calendar: .current)
        let interval = resolvedInterval.interval
        let selectedCalendars = query.calendarIDs.map { identifiers in
            store.calendars(for: .event).filter { identifiers.contains($0.calendarIdentifier) }
        }
        let visibleCalendarIDs = Set(
            calendars
                .filter { !hiddenCalendarIDs.contains($0.id) }
                .map(\.id)
        )
        let effectiveCalendarIDs = query.calendarIDs.map { identifiers in
            identifiers.intersection(visibleCalendarIDs)
        } ?? visibleCalendarIDs
        guard !effectiveCalendarIDs.isEmpty else {
            searchResults = []
            searchRangeWasCapped = resolvedInterval.wasCapped
            searchResultLimitReached = false
            isSearching = false
            return
        }

        let matchedEvents = await Task.detached(priority: .userInitiated) { [store, selectedCalendars] in
            let predicate = store.predicateForEvents(
                withStart: interval.start,
                end: interval.end,
                calendars: selectedCalendars?.isEmpty == true ? [] : selectedCalendars
            )
            return store.events(matching: predicate).map(CalendarEvent.init(from:))
        }.value

        guard requestGeneration == searchRequestGeneration else { return }

        let indexedEventIDs = await Task.detached(priority: .userInitiated) { () -> [String]? in
            let records = matchedEvents.map { event in
                IndexedEventRecord(
                    eventID: event.id,
                    calendarID: event.calendarIdentifier ?? "",
                    title: event.title,
                    location: event.location,
                    notes: event.notes,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay
                )
            }

            do {
                let index = try EventSearchIndex(databaseURL: Self.searchIndexURL())
                try index.replaceAll(records)
                return try index.search(
                    keyword: trimmedQuery,
                    interval: interval,
                    calendarIDs: effectiveCalendarIDs,
                    includeAllDay: query.includeAllDay,
                    limit: EventSearchIndex.resultLimit + 1
                ).map(\.eventID)
            } catch {
                return nil
            }
        }.value

        guard requestGeneration == searchRequestGeneration else { return }

        let filteredEvents: [CalendarEvent]
        if let indexedEventIDs {
            let eventsByID = Dictionary(uniqueKeysWithValues: matchedEvents.map { ($0.id, $0) })
            filteredEvents = indexedEventIDs.compactMap { eventsByID[$0] }
        } else {
            filteredEvents = matchedEvents
                .filter { effectiveCalendarIDs.contains($0.calendarIdentifier ?? "") }
                .filter { query.includeAllDay || !$0.isAllDay }
                .filter { event in
                    let fields = [
                        event.title,
                        event.location,
                        event.notes
                    ].compactMap { $0 }
                    return fields.contains { $0.localizedStandardContains(trimmedQuery) }
                }
                .sorted { lhs, rhs in
                    let currentCalendar = Calendar.current
                    if currentCalendar.isDate(lhs.startDate, inSameDayAs: rhs.startDate),
                       lhs.isAllDay != rhs.isAllDay {
                        return lhs.isAllDay
                    }
                    return lhs.startDate < rhs.startDate
                }
        }

        searchResultLimitReached = filteredEvents.count > 200
        searchResults = Array(filteredEvents.prefix(200))
        searchRangeWasCapped = resolvedInterval.wasCapped
        isSearching = false
    }

    private nonisolated static func searchIndexURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return directory.appendingPathComponent("EventSearchIndex.sqlite")
    }

    func saveEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String?,
        reminderOption: EventReminderOption,
        recurrenceDraft: EventRecurrenceDraft
    ) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAllDay || endDate > startDate else { throw EventStoreError.invalidDates }

        let selectedCalendar = calendarIdentifier.flatMap { store.calendar(withIdentifier: $0) }
        let calendar = selectedCalendar ?? store.defaultCalendarForNewEvents
        guard let targetCalendar = calendar, targetCalendar.allowsContentModifications else {
            throw EventStoreError.noWritableCalendar
        }

        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = EKEvent(eventStore: store)
        event.title = trimmedTitle.isEmpty ? "新日程" : trimmedTitle
        event.startDate = isAllDay ? Calendar.current.startOfDay(for: startDate) : startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = trimmedLocation?.isEmpty == false ? trimmedLocation : nil
        event.notes = trimmedNotes?.isEmpty == false ? trimmedNotes : nil
        event.calendar = targetCalendar
        applyRecurrence(recurrenceDraft, to: event, shouldPreserve: false)
        applyReminder(reminderOption, to: event)

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            throw EventStoreError.saveFailed(error.localizedDescription)
        }

        lastErrorMessage = nil
        await reloadIfNecessary()
    }

    func updateEvent(
        _ model: CalendarEvent,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String?,
        reminderOption: EventReminderOption,
        recurrenceDraft: EventRecurrenceDraft,
        editScope: EventEditScope = .thisEvent
    ) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }
        guard isAllDay || endDate > startDate else { throw EventStoreError.invalidDates }

        guard let matchedEvent = ekEvent(matching: model) else {
            throw EventStoreError.eventNotFound
        }
        let storedEvent = masterEventIfNeeded(matchedEvent, model: model, scope: editScope)
        guard storedEvent.calendar?.allowsContentModifications == true else {
            throw EventStoreError.readOnlyEvent
        }

        let selectedCalendar = calendarIdentifier.flatMap { store.calendar(withIdentifier: $0) }
        let targetCalendar = selectedCalendar ?? storedEvent.calendar
        guard let targetCalendar, targetCalendar.allowsContentModifications else {
            throw EventStoreError.noWritableCalendar
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)

        storedEvent.title = trimmedTitle.isEmpty ? "无标题日程" : trimmedTitle
        storedEvent.startDate = isAllDay ? Calendar.current.startOfDay(for: startDate) : startDate
        storedEvent.endDate = endDate
        storedEvent.isAllDay = isAllDay
        storedEvent.location = trimmedLocation?.isEmpty == false ? trimmedLocation : nil
        storedEvent.notes = trimmedNotes?.isEmpty == false ? trimmedNotes : nil
        storedEvent.calendar = targetCalendar
        applyRecurrence(
            recurrenceDraft,
            to: storedEvent,
            shouldPreserve: model.hasRecurrenceRules && editScope == .thisEvent
        )
        applyReminder(reminderOption, to: storedEvent)

        do {
            try store.save(storedEvent, span: saveSpan(for: model, scope: editScope))
        } catch {
            throw EventStoreError.saveFailed(error.localizedDescription)
        }

        lastErrorMessage = nil
        await reloadIfNecessary()
    }

    func deleteEvent(
        _ model: CalendarEvent,
        scope: EventEditScope = .thisEvent
    ) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }

        guard let matchedEvent = ekEvent(matching: model) else {
            throw EventStoreError.eventNotFound
        }
        let storedEvent = masterEventIfNeeded(matchedEvent, model: model, scope: scope)
        guard storedEvent.calendar?.allowsContentModifications == true else {
            throw EventStoreError.readOnlyEvent
        }

        do {
            try store.remove(storedEvent, span: saveSpan(for: model, scope: scope))
        } catch {
            throw EventStoreError.deleteFailed(error.localizedDescription)
        }

        lastErrorMessage = nil
        await reloadIfNecessary()
    }

    func events(on day: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter {
            isCalendarVisible($0.calendarIdentifier) && $0.startDate < end && $0.endDate > start
        }
    }

    func visibleAnalysisEvents(overlapping interval: DateInterval) -> [AnalysisEvent] {
        events
            .filter { event in
                guard isCalendarVisible(event.calendarIdentifier) else { return false }
                return event.startDate < interval.end && event.endDate > interval.start
            }
            .map(\.analysisEvent)
    }

    func event(with model: CalendarEvent) -> CalendarEvent? {
        guard let storedEvent = ekEvent(matching: model) else { return nil }
        return CalendarEvent(from: storedEvent)
    }

    func eventDayMarks(for month: Date) -> Set<Date> {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var marks = Set<Date>()

        for event in events where isCalendarVisible(event.calendarIdentifier) {
            var day = calendar.startOfDay(for: max(event.startDate, interval.start))
            let end = min(event.endDate.addingTimeInterval(-1), interval.end.addingTimeInterval(-1))
            while day < end {
                marks.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return marks
    }

    func eventCalendarColors(for month: Date) -> [Date: [CalendarColorComponents]] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        var marks: [Date: [CalendarColorComponents]] = [:]

        for event in events where isCalendarVisible(event.calendarIdentifier) {
            guard let color = event.calendarColor else { continue }
            var day = calendar.startOfDay(for: max(event.startDate, interval.start))
            let end = min(event.endDate.addingTimeInterval(-1), interval.end.addingTimeInterval(-1))

            while day < end {
                var colors = marks[day, default: []]
                if !colors.contains(color) {
                    colors.append(color)
                }
                marks[day] = colors
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        return marks.mapValues { Array($0.prefix(3)) }
    }

    private func reloadIfNecessary() async {
        guard accessState == .granted, let interval = loadedInterval else { return }
        await loadEvents(from: interval.start, to: interval.end)
    }

    private func refreshAfterCalendarMetadataChange() async {
        loadCalendars()
        loadWritableCalendars()
        await reloadIfNecessary()
    }

    private func ekEvent(matching model: CalendarEvent) -> EKEvent? {
        let searchStart = model.startDate.addingTimeInterval(-60 * 60 * 24)
        let searchEnd = model.endDate.addingTimeInterval(60 * 60 * 24)
        let predicate = store.predicateForEvents(withStart: searchStart, end: searchEnd, calendars: nil)

        return store.events(matching: predicate).first { candidate in
            let candidateIdentifier = candidate.eventIdentifier ?? candidate.calendarItemExternalIdentifier
            let identifierMatches = model.eventIdentifier == nil || candidateIdentifier == model.eventIdentifier
            let occurrenceMatches = candidate.startDate == model.startDate && candidate.endDate == model.endDate
            return identifierMatches && occurrenceMatches
        }
    }

    private func masterEventIfNeeded(
        _ event: EKEvent,
        model: CalendarEvent,
        scope: EventEditScope
    ) -> EKEvent {
        guard model.hasRecurrenceRules, scope == .wholeSeries,
              let identifier = model.eventIdentifier,
              let master = store.event(withIdentifier: identifier) else {
            return event
        }
        return master
    }

    private func saveSpan(for model: CalendarEvent, scope: EventEditScope) -> EKSpan {
        guard model.hasRecurrenceRules else { return .thisEvent }
        switch scope {
        case .thisEvent:
            return .thisEvent
        case .futureEvents, .wholeSeries:
            return .futureEvents
        }
    }

    private func applyReminder(_ option: EventReminderOption, to event: EKEvent) {
        guard option != .preserveExisting else { return }

        switch option {
        case .none:
            event.alarms = nil
        case .atStart:
            event.alarms = [EKAlarm(relativeOffset: 0)]
        case .minutesBefore(let minutes):
            event.alarms = [EKAlarm(relativeOffset: -Double(minutes * 60))]
        case .preserveExisting:
            break
        }
    }

    private func persistHiddenCalendarIDs() {
        UserDefaults.standard.set(
            hiddenCalendarIDs.sorted(),
            forKey: hiddenCalendarIDsKey
        )
    }

    private func applyRecurrence(
        _ draft: EventRecurrenceDraft,
        to event: EKEvent,
        shouldPreserve: Bool
    ) {
        guard !shouldPreserve, draft.mode != .preserveExisting else { return }
        event.recurrenceRules = draft.makeRule(startDate: event.startDate).map { [$0] }
    }

    private func refreshAuthorizationState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, macOS 14.0, *) {
            switch status {
            case .fullAccess:
                accessState = .granted
            case .writeOnly:
                // 只写权限无法展示用户已有日程，对 App 视为不可用。
                accessState = .denied
            case .notDetermined:
                accessState = .notDetermined
            default:
                accessState = .denied
            }
            return
        }

        switch status {
        case .authorized:
            accessState = .granted
        case .notDetermined:
            accessState = .notDetermined
        default:
            accessState = .denied
        }
    }
}
