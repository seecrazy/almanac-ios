import Foundation

/// App 待发本地通知的系统配额与三类通知的标识前缀。
/// 闹钟、里程碑提醒与每日简报共用 64 条上限，调度前必须互相预留。
public enum NotificationBudgetPlanner {
    /// iOS 允许的待发本地通知上限，超出部分被系统静默丢弃。
    public static let systemPendingLimit = 64

    public static let alarmIdentifierPrefix = "workday-alarm."
    public static let milestoneIdentifierPrefix = "milestone."
    public static let briefingIdentifierPrefix = "daily-brief."

    /// 输入须按触发时间升序；保留最早触发的 `budget` 条。
    public static func trimming<T>(_ items: [T], budget: Int) -> [T] {
        guard budget > 0 else { return [] }
        return Array(items.prefix(budget))
    }

    /// 64 减去其它前缀已占用的待发数量；结果下限 0。
    public static func budget(reserving reservedCount: Int) -> Int {
        max(0, systemPendingLimit - max(0, reservedCount))
    }
}
