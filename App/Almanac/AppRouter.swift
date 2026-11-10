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

    /// 解析 Widget / 快捷指令的 `almanac://` 深链。
    /// 支持 `almanac://calendar|countdown|alarm|settings`，`calendar?date=yyyy-MM-dd` 打开该日详情。
    func handleURL(_ url: URL) {
        guard url.scheme == "almanac" else { return }

        switch url.host {
        case "calendar":
            selectedTab = .calendar
            if let dateText = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "date" })?
                .value {
                let parts = dateText.split(separator: "-").compactMap { Int($0) }
                if parts.count == 3 {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = .current
                    if let date = calendar.date(from: DateComponents(
                        year: parts[0], month: parts[1], day: parts[2]
                    )) {
                        pendingDiaryDate = date
                    }
                }
            }
        case "countdown":
            selectedTab = .countdown
        case "alarm":
            selectedTab = .alarm
        case "settings":
            selectedTab = .settings
        default:
            break
        }
    }

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
