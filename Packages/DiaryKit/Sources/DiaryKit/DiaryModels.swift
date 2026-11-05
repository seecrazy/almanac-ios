import Foundation

public enum DiaryMood: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case great
    case good
    case calm
    case tired
    case sad

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .great: return "很好"
        case .good: return "不错"
        case .calm: return "平静"
        case .tired: return "疲惫"
        case .sad: return "低落"
        }
    }

    public var symbolName: String {
        switch self {
        case .great: return "face.smiling.inverse"
        case .good: return "face.smiling"
        case .calm: return "face.dashed"
        case .tired: return "moon.zzz"
        case .sad: return "cloud.rain"
        }
    }
}

public struct DiarySkeletonItem: Codable, Hashable, Sendable, Identifiable {
    public var title: String
    public var timeText: String
    public var calendarTitle: String
    public var isAllDay: Bool

    public var id: String {
        [timeText, calendarTitle, title, isAllDay ? "all-day" : "timed"]
            .joined(separator: "|")
    }

    public init(
        title: String,
        timeText: String,
        calendarTitle: String,
        isAllDay: Bool
    ) {
        self.title = title
        self.timeText = timeText
        self.calendarTitle = calendarTitle
        self.isAllDay = isAllDay
    }
}

public struct DiaryEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var mood: DiaryMood?
    public var body: String
    public var skeleton: [DiarySkeletonItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        mood: DiaryMood? = nil,
        body: String = "",
        skeleton: [DiarySkeletonItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.mood = mood
        self.body = body
        self.skeleton = skeleton
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var normalizedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func normalized(calendar: Calendar = .current) -> DiaryEntry {
        DiaryEntry(
            id: id,
            date: date,
            mood: mood,
            body: body,
            skeleton: skeleton,
            createdAt: createdAt,
            updatedAt: updatedAt,
            calendar: calendar
        )
    }

    public var canSave: Bool {
        normalizedBody.count <= DiaryEntry.maximumBodyLength
            && (!normalizedBody.isEmpty || mood != nil)
    }

    public static let maximumBodyLength = 20_000
}

public enum DiaryLimit {
    public static let searchDays = 365
    public static let searchResults = 100
    public static let recentDays = 30
}
