#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import MilestoneKit

/// 里程碑 Live Activity 调度：始终只保留"最近一条 24 小时内的时刻里程碑"。
/// 在 MilestoneStore.refreshPlatformState 后调用；未授权 / 无候选时结束全部既有活动。
@available(iOS 16.1, *)
enum LiveActivityScheduler {
    static let window: TimeInterval = 24 * 60 * 60

    @MainActor
    static func sync(milestones: [Milestone], referenceDate: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endAll()
            return
        }

        let candidate = milestones
            .filter { !$0.isAllDay && $0.targetDate > referenceDate }
            .filter { $0.targetDate.timeIntervalSince(referenceDate) <= window }
            .min { $0.targetDate < $1.targetDate }

        Task { await syncActivity(for: candidate, referenceDate: referenceDate) }
    }

    private static func syncActivity(for milestone: Milestone?, referenceDate: Date) async {
        let existing = Activity<MilestoneCountdownAttributes>.activities

        guard let milestone else {
            for activity in existing {
                await activity.end(dismissalPolicy: .immediate)
            }
            return
        }

        let attributes = MilestoneCountdownAttributes(
            title: milestone.title,
            categoryTitle: milestone.category.title
        )
        let state = MilestoneCountdownAttributes.ContentState(
            targetDate: milestone.targetDate
        )

        if let current = existing.first {
            await current.update(using: state)
            for extra in existing.dropFirst() {
                await extra.end(dismissalPolicy: .immediate)
            }
            return
        }

        _ = try? Activity.request(
            attributes: attributes,
            contentState: state
        )
    }

    private static func endAll() {
        Task {
            for activity in Activity<MilestoneCountdownAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
