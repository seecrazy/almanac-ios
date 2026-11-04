import Foundation
import MilestoneKit

enum MilestoneCategory: String, Codable, CaseIterable, Identifiable {
    case exam
    case project
    case travel
    case anniversary
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exam: return "考试"
        case .project: return "项目"
        case .travel: return "出行"
        case .anniversary: return "纪念日"
        case .custom: return "自定义"
        }
    }

    var icon: String {
        switch self {
        case .exam: return "🎓"
        case .project: return "🚀"
        case .travel: return "✈️"
        case .anniversary: return "💛"
        case .custom: return "⭐️"
        }
    }
}

struct Milestone: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var targetDate: Date
    var isAllDay: Bool
    var category: MilestoneCategory
    var notes: String
    var createdAt: Date
    var reminders: [MilestoneReminder]

    var effectiveSortDate: Date {
        isAllDay ? Calendar.current.startOfDay(for: targetDate) : targetDate
    }

    init(
        id: UUID,
        title: String,
        targetDate: Date,
        isAllDay: Bool,
        category: MilestoneCategory,
        notes: String,
        createdAt: Date,
        reminders: [MilestoneReminder] = []
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.isAllDay = isAllDay
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
        self.reminders = reminders
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case targetDate
        case isAllDay
        case category
        case notes
        case createdAt
        case reminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        category = try container.decode(MilestoneCategory.self, forKey: .category)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        reminders = try container.decodeIfPresent(
            [MilestoneReminder].self,
            forKey: .reminders
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(targetDate, forKey: .targetDate)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encode(category, forKey: .category)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(reminders, forKey: .reminders)
    }
}

struct MilestoneCountdown: Hashable {
    let primaryText: String
    let unitText: String
    let detailText: String?
    let isPast: Bool
}

@MainActor
final class MilestoneStore: ObservableObject {
    @Published private(set) var milestones: [Milestone] = []
    @Published private(set) var notificationAuthorization: MilestoneNotificationAuthorizationState = .notDetermined
    @Published private(set) var snapshotAvailable = false

    private let defaults: UserDefaults
    private let storageKey: String
    private let platformService: MilestonePlatformService

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "milestones.v1",
        platformService: MilestonePlatformService = MilestonePlatformService()
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.platformService = platformService
        loadMilestones()
    }

    var refreshInterval: TimeInterval {
        milestones.contains { !$0.isAllDay } ? 1 : 60
    }

    func sortedMilestones(at referenceDate: Date) -> [Milestone] {
        let now = referenceDate
        let future = milestones
            .filter { $0.effectiveSortDate >= now }
            .sorted { $0.effectiveSortDate < $1.effectiveSortDate }
        let past = milestones
            .filter { $0.effectiveSortDate < now }
            .sorted { $0.effectiveSortDate > $1.effectiveSortDate }
        return future + past
    }

    func milestones(on day: Date) -> [Milestone] {
        milestones.filter {
            Calendar.current.isDate($0.targetDate, inSameDayAs: day)
        }
    }

    func save(_ milestone: Milestone) async {
        if let index = milestones.firstIndex(where: { $0.id == milestone.id }) {
            milestones[index] = milestone
        } else {
            milestones.append(milestone)
        }
        persist()
        await refreshPlatformState(shouldRequestAuthorization: !milestone.reminders.isEmpty)
    }

    func remove(_ milestone: Milestone) async {
        milestones.removeAll { $0.id == milestone.id }
        persist()
        await refreshPlatformState(shouldRequestAuthorization: false)
    }

    func refreshPlatformState(shouldRequestAuthorization: Bool = false) async {
        let result = await platformService.sync(
            milestones: milestones,
            referenceDate: Date(),
            shouldRequestAuthorization: shouldRequestAuthorization
        )
        notificationAuthorization = result.authorization
        snapshotAvailable = result.snapshotAvailable
    }

    func countdown(for milestone: Milestone, at referenceDate: Date) -> MilestoneCountdown {
        let calendar = Calendar.current

        if milestone.isAllDay {
            let today = calendar.startOfDay(for: referenceDate)
            let target = calendar.startOfDay(for: milestone.targetDate)
            let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

            if days == 0 {
                return MilestoneCountdown(primaryText: "今天", unitText: "", detailText: nil, isPast: false)
            }
            if days == 1 {
                return MilestoneCountdown(primaryText: "明天", unitText: "", detailText: nil, isPast: false)
            }
            if days > 0 {
                return MilestoneCountdown(
                    primaryText: "\(days)",
                    unitText: "天后",
                    detailText: nil,
                    isPast: false
                )
            }
            return MilestoneCountdown(
                primaryText: "\(abs(days))",
                unitText: "天前",
                detailText: nil,
                isPast: true
            )
        }

        let interval = milestone.targetDate.timeIntervalSince(referenceDate)
        if interval <= 0 {
            let pastDays = Int(abs(interval) / 86_400)
            return MilestoneCountdown(
                primaryText: pastDays > 0 ? "\(pastDays)" : "已开始",
                unitText: pastDays > 0 ? "天前" : "",
                detailText: nil,
                isPast: true
            )
        }

        let totalSeconds = Int(interval.rounded())
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if days >= 7 {
            return MilestoneCountdown(
                primaryText: "\(days)",
                unitText: "天后",
                detailText: "\(hours) 小时后",
                isPast: false
            )
        }
        if days >= 1 {
            return MilestoneCountdown(
                primaryText: "\(days)天 \(hours)小时",
                unitText: "后",
                detailText: "\(minutes) 分钟后",
                isPast: false
            )
        }

        let clockText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        return MilestoneCountdown(
            primaryText: clockText,
            unitText: "",
            detailText: "倒计时进行中",
            isPast: false
        )
    }

    private func loadMilestones() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        milestones = (try? decoder.decode([Milestone].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(milestones) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
