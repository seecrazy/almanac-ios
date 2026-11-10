import Foundation

/// watchOS 端"今日一瞥"快照：iOS 侧写入 App Group，手表只读（ADR-012）。
/// 字段由 iOS 侧预计算（农历文本 / 节气 / 节日 / 宜忌 / 下一个里程碑 / 下一次闹钟）。
public struct WatchBriefingSnapshot: Codable, Hashable, Sendable {
    public static let version = 1

    public let version: Int
    public let generatedAt: Date
    /// 覆盖当天（零点）。
    public let day: Date
    /// 如「农历九月廿一 · 甲辰年」。
    public let lunarText: String
    public let festivalText: String?
    public let solarTermText: String?
    /// 如「宜：祭祀、出行」。
    public let suitableText: String?
    public let avoidText: String?
    public let nextMilestoneTitle: String?
    public let nextMilestoneDate: Date?
    public let nextAlarmName: String?
    public let nextAlarmFireDate: Date?
    public let todayEventCount: Int

    public init(
        generatedAt: Date,
        day: Date,
        lunarText: String,
        festivalText: String?,
        solarTermText: String?,
        suitableText: String?,
        avoidText: String?,
        nextMilestoneTitle: String?,
        nextMilestoneDate: Date?,
        nextAlarmName: String?,
        nextAlarmFireDate: Date?,
        todayEventCount: Int
    ) {
        self.version = Self.version
        self.generatedAt = generatedAt
        self.day = day
        self.lunarText = lunarText
        self.festivalText = festivalText
        self.solarTermText = solarTermText
        self.suitableText = suitableText
        self.avoidText = avoidText
        self.nextMilestoneTitle = nextMilestoneTitle
        self.nextMilestoneDate = nextMilestoneDate
        self.nextAlarmName = nextAlarmName
        self.nextAlarmFireDate = nextAlarmFireDate
        self.todayEventCount = todayEventCount
    }
}

public enum WatchBriefingStorage {
    public static let appGroupIdentifier = MilestoneSnapshotStorage.appGroupIdentifier
    public static let fileName = "watch-briefing.json"
}
