#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

/// 里程碑秒级倒计时 Live Activity 的共享属性（App 与 Widget 同一类型）。
@available(iOS 16.1, *)
public struct MilestoneCountdownAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var targetDate: Date

        public init(targetDate: Date) {
            self.targetDate = targetDate
        }
    }

    public var title: String
    public var categoryTitle: String

    public init(title: String, categoryTitle: String) {
        self.title = title
        self.categoryTitle = categoryTitle
    }
}
#endif
