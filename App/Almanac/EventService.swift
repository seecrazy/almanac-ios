import EventKit
import Foundation

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
    let isWritable: Bool
    let hasRecurrenceRules: Bool
    let reminderOption: EventReminderOption
    let reminderSummary: String
    let hasUnsupportedAlarms: Bool

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
        self.isWritable = event.calendar?.allowsContentModifications == true
        self.hasRecurrenceRules = !(event.recurrenceRules?.isEmpty ?? true)
        self.reminderOption = EventReminderOption(from: event.alarms ?? [])
        self.reminderSummary = EventReminderOption.summary(for: event.alarms ?? [])
        self.hasUnsupportedAlarms = EventReminderOption(from: event.alarms ?? []) == .preserveExisting
    }
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
    case eventNotFound
    case readOnlyEvent
    case saveFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "没有系统日历写入权限"
        case .invalidDates:
            return "结束时间必须晚于开始时间"
        case .noWritableCalendar:
            return "没有可写入的日历"
        case .eventNotFound:
            return "日程不存在或已被删除"
        case .readOnlyEvent:
            return "该日历只读，不能修改或删除"
        case .saveFailed(let message):
            return message
        case .deleteFailed(let message):
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

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private var loadedInterval: DateInterval?

    init() {
        refreshAuthorizationState()
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.reloadIfNecessary() }
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
            await reloadIfNecessary()
        } else {
            lastErrorMessage = "未获得日历访问权限"
        }
    }

    func loadEvents(from start: Date, to end: Date) async {
        refreshAuthorizationState()
        guard accessState == .granted else { return }
        let interval = DateInterval(start: start, end: max(start, end))
        loadedInterval = interval

        let fetchedEvents = await Task.detached(priority: .userInitiated) { [store] in
            let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
            return store.events(matching: predicate).map(CalendarEvent.init(from:))
        }.value

        events = fetchedEvents.sorted {
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

    func selectedWritableCalendarID(fallback: String?) -> String? {
        let preferredID = fallback ?? defaultCalendarIdentifier
        if let preferredID,
           writableCalendars.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        return writableCalendars.first?.id
    }

    func saveEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        calendarIdentifier: String?,
        reminderOption: EventReminderOption
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
        reminderOption: EventReminderOption
    ) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }
        guard isAllDay || endDate > startDate else { throw EventStoreError.invalidDates }

        guard let storedEvent = ekEvent(matching: model) else {
            throw EventStoreError.eventNotFound
        }
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
        applyReminder(reminderOption, to: storedEvent)

        do {
            try store.save(storedEvent, span: .thisEvent)
        } catch {
            throw EventStoreError.saveFailed(error.localizedDescription)
        }

        lastErrorMessage = nil
        await reloadIfNecessary()
    }

    func deleteEvent(_ model: CalendarEvent) async throws {
        refreshAuthorizationState()
        guard accessState == .granted else { throw EventStoreError.accessDenied }

        guard let storedEvent = ekEvent(matching: model) else {
            throw EventStoreError.eventNotFound
        }
        guard storedEvent.calendar?.allowsContentModifications == true else {
            throw EventStoreError.readOnlyEvent
        }

        do {
            try store.remove(storedEvent, span: .thisEvent)
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
        return events.filter { $0.startDate < end && $0.endDate > start }
    }

    func event(with model: CalendarEvent) -> CalendarEvent? {
        guard let storedEvent = ekEvent(matching: model) else { return nil }
        return CalendarEvent(from: storedEvent)
    }

    func eventDayMarks(for month: Date) -> Set<Date> {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var marks = Set<Date>()

        for event in events {
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

    private func reloadIfNecessary() async {
        guard accessState == .granted, let interval = loadedInterval else { return }
        await loadEvents(from: interval.start, to: interval.end)
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
