import EventKit
import Foundation

/// App 内使用的轻量日程模型，避免 EventKit 类型穿透 UI。
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let calendarTitle: String
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
            return store.events(matching: predicate).map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? event.calendarItemExternalIdentifier,
                    title: event.title?.isEmpty == false ? event.title! : "无标题日程",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    notes: event.notes,
                    calendarTitle: event.calendar?.title ?? "日历"
                )
            }
        }.value

        events = fetchedEvents.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.startDate == $1.startDate { return $0.endDate < $1.endDate }
            return $0.startDate < $1.startDate
        }
    }

    func events(on day: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter { $0.startDate < end && $0.endDate > start }
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
