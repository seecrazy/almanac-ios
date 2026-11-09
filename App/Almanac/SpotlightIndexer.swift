import CoreSpotlight
import Foundation
import MilestoneKit

/// Spotlight 索引：里程碑 / 纪念日按标题索引；日记因正文加密，只按日期索引（不进正文关键词）。
/// 命中后经 CSSearchableItemActionType → AppRouter 深链。
enum SpotlightIndexer {
    static let domainIdentifier = "com.yili.almanac.spotlight"
    static let milestoneIDPrefix = "milestone."
    static let anniversaryIDPrefix = "anniversary."
    static let diaryIDPrefix = "diary."

    /// 里程碑 / 纪念日整体重建（数据量小，全量替换最简单可靠）。
    static func reindex(milestones: [Milestone], anniversaries: [Anniversary]) {
        let items = milestones.map { item(for: $0) } + anniversaries.map { item(for: $0) }
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { _ in
            guard !items.isEmpty else { return }
            CSSearchableIndex.default().indexSearchableItems(items, completionHandler: nil)
        }
    }

    /// 日记只索引日期与心情；正文为加密内容，绝不进入系统索引。
    static func indexDiary(date: Date, moodTitle: String?) {
        let day = Calendar.current.startOfDay(for: date)
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = "\(AppFormatters.monthDayWeekday.string(from: day))的日记"
        attributes.contentDescription = moodTitle.map { "心情：\($0)" } ?? "宜历加密日记"
        attributes.keywords = ["日记", "宜历", AppFormatters.fullDate.string(from: day)]

        let item = CSSearchableItem(
            uniqueIdentifier: diaryIdentifier(for: day),
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    static func removeDiary(date: Date) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [diaryIdentifier(for: Calendar.current.startOfDay(for: date))],
            completionHandler: nil
        )
    }

    static func diaryIdentifier(for day: Date) -> String {
        "\(diaryIDPrefix)\(AppFormatters.alarmIdentifierDate.string(from: day))"
    }

    private static func item(for milestone: Milestone) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = milestone.title
        attributes.contentDescription = "倒计时 · \(milestone.category.title)"
        attributes.keywords = [milestone.title, "倒计时", "里程碑", "宜历"]

        return CSSearchableItem(
            uniqueIdentifier: "\(milestoneIDPrefix)\(milestone.id.uuidString)",
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
    }

    private static func item(for anniversary: Anniversary) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = anniversary.title
        let calendarText: String
        if case .lunar = anniversary.calendar {
            calendarText = "农历"
        } else {
            calendarText = "公历"
        }
        attributes.contentDescription = "生日 / 纪念日 · \(calendarText)"
        attributes.keywords = [anniversary.title, "生日", "纪念日", "宜历"]

        return CSSearchableItem(
            uniqueIdentifier: "\(anniversaryIDPrefix)\(anniversary.id.uuidString)",
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
    }
}
