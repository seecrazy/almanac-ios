import CoreSpotlight
import Foundation
import SwiftUI

/// 全局导航路由：Tab 选择 + Spotlight 深链载荷。
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Int {
        case calendar = 0
        case countdown
        case alarm
        case settings
    }

    @Published var selectedTab: Tab = .calendar
    /// Spotlight 命中后待打开的载荷；对应视图消费后置 nil。
    @Published var pendingMilestoneID: UUID?
    @Published var pendingAnniversaryID: UUID?
    @Published var pendingDiaryDate: Date?
    /// App Intents 传入的自然语言短语；月视图消费后置 nil。
    @Published var pendingQuickPhrase: String?

    /// 解析 Spotlight 的 CSSearchableItemActionType 活动。
    func handleSearchableItemActivity(identifier: String) {
        if identifier.hasPrefix(SpotlightIndexer.milestoneIDPrefix),
           let id = UUID(uuidString: String(identifier.dropFirst(SpotlightIndexer.milestoneIDPrefix.count))) {
            selectedTab = .countdown
            pendingMilestoneID = id
        } else if identifier.hasPrefix(SpotlightIndexer.anniversaryIDPrefix),
                  let id = UUID(uuidString: String(identifier.dropFirst(SpotlightIndexer.anniversaryIDPrefix.count))) {
            selectedTab = .countdown
            pendingAnniversaryID = id
        } else if identifier.hasPrefix(SpotlightIndexer.diaryIDPrefix) {
            // 日记标识为 yyyy-MM-dd。
            let components = String(identifier.dropFirst(SpotlightIndexer.diaryIDPrefix.count))
                .split(separator: "-")
                .compactMap { Int($0) }
            if components.count == 3 {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = .current
                if let date = calendar.date(from: DateComponents(
                    year: components[0], month: components[1], day: components[2]
                )) {
                    selectedTab = .calendar
                    pendingDiaryDate = date
                }
            }
        }
    }
}
