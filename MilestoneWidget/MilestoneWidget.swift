import Foundation
import MilestoneKit
import SwiftUI
import WidgetKit

struct MilestoneWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: MilestoneSnapshot?
}

struct MilestoneSnapshotReader {
    func read() -> MilestoneSnapshot? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: MilestoneSnapshotStorage.appGroupIdentifier
        ) else {
            return nil
        }

        let url = container
            .appendingPathComponent("Widgets", isDirectory: true)
            .appendingPathComponent(MilestoneSnapshotStorage.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MilestoneSnapshot.self, from: data)
    }
}

struct MilestoneWidgetProvider: TimelineProvider {
    private let reader = MilestoneSnapshotReader()

    func placeholder(in context: Context) -> MilestoneWidgetEntry {
        MilestoneWidgetEntry(
            date: Date(),
            snapshot: MilestoneSnapshot(
                generatedAt: Date(),
                milestones: [
                    MilestoneSnapshotItem(
                        id: UUID(),
                        title: "高考",
                        targetDate: Calendar.current.date(byAdding: .day, value: 180, to: Date()) ?? Date(),
                        isAllDay: true,
                        category: "exam"
                    )
                ]
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (MilestoneWidgetEntry) -> Void
    ) {
        completion(entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<MilestoneWidgetEntry>) -> Void
    ) {
        let currentEntry = entry()
        let refreshDate = nextRefreshDate(
            after: currentEntry.date,
            snapshot: currentEntry.snapshot
        )
        completion(Timeline(
            entries: [currentEntry],
            policy: .after(refreshDate)
        ))
    }

    private func entry() -> MilestoneWidgetEntry {
        MilestoneWidgetEntry(date: Date(), snapshot: reader.read())
    }

    private func nextRefreshDate(
        after date: Date,
        snapshot: MilestoneSnapshot?
    ) -> Date {
        let regularRefresh = date.addingTimeInterval(15 * 60)
        guard let first = snapshot?.milestones.first else {
            return date.addingTimeInterval(60 * 60)
        }

        let calendar = Calendar.current
        let target = first.isAllDay
            ? calendar.startOfDay(for: first.targetDate)
            : first.targetDate
        let targetDay = calendar.startOfDay(for: target)
        let reminderDays = [-7, -1, 0]
        let reminderTimes = reminderDays.compactMap { dayOffset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: targetDay) else {
                return nil
            }
            return calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: day
            )
        } + [target]
        let firstImportantTime = reminderTimes
            .filter { $0 > date }
            .map { $0.addingTimeInterval(60) }
            .min() ?? regularRefresh
        return min(regularRefresh, firstImportantTime)
    }
}

struct MilestoneWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MilestoneWidgetEntry

    var body: some View {
        familyContent
            .widgetBackground()
    }

    @ViewBuilder
    private var familyContent: some View {
        switch family {
        case .accessoryCircular:
            circularContent
        case .accessoryInline:
            inlineContent
        case .accessoryRectangular:
            rectangularContent
        default:
            systemContent
        }
    }

    @ViewBuilder
    private var systemContent: some View {
        if let snapshot = entry.snapshot {
            if snapshot.milestones.isEmpty {
                emptyView
            } else {
                content(snapshot: snapshot)
            }
        } else {
            missingSnapshotView
        }
    }

    private var circularContent: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.35), lineWidth: 2)
            if let milestone = entry.snapshot?.milestones.first {
                VStack(spacing: 1) {
                    Text(circularCountdownText(milestone))
                        .font(.system(size: 19, weight: .semibold, design: .serif))
                }
            } else {
                Text("宜历")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
            }
        }
    }

    private var inlineContent: some View {
        if let milestone = entry.snapshot?.milestones.first {
            Text("\(milestone.title) · \(compactCountdownText(milestone))")
        } else {
            Text("打开宜历更新数据")
        }
    }

    @ViewBuilder
    private var rectangularContent: some View {
        if let milestone = entry.snapshot?.milestones.first {
            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(milestone.category)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(compactCountdownText(milestone))
                    .font(.system(size: 12, weight: .medium))
            }
        } else {
            Text("打开宜历更新数据")
                .font(.system(size: 12))
        }
    }

    private func content(snapshot: MilestoneSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("重要日子")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if let milestone = snapshot.milestones.first {
                Text(milestone.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(targetText(milestone))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(countdownText(milestone))
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if snapshot.milestones.count > 1 {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(snapshot.milestones.dropFirst().prefix(2)) { milestone in
                        HStack {
                            Text(milestone.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(compactCountdownText(milestone))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("添加第一个倒计时")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            Text("打开宜历添加重要日子")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var missingSnapshotView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("打开宜历更新数据")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            Text("小组件暂无法读取共享快照")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func targetText(_ milestone: MilestoneSnapshotItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = milestone.isAllDay ? "M月d日" : "M月d日 HH:mm"
        return formatter.string(from: milestone.targetDate)
    }

    private func countdownText(_ milestone: MilestoneSnapshotItem) -> String {
        let calendar = Calendar.current
        if milestone.isAllDay {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: entry.date),
                to: calendar.startOfDay(for: milestone.targetDate)
            ).day ?? 0
            if days == 0 { return "今天" }
            if days == 1 { return "明天" }
            return days > 0 ? "\(days) 天" : "已过期"
        }

        if milestone.targetDate <= entry.date { return "已到期" }
        let interval = milestone.targetDate.timeIntervalSince(entry.date)
        let days = Int(interval / 86_400)
        if days >= 1 { return "\(days) 天" }
        let hours = Int(interval / 3_600)
        if hours >= 1 { return "\(hours) 小时" }
        return "即将开始"
    }

    private func compactCountdownText(_ milestone: MilestoneSnapshotItem) -> String {
        countdownText(milestone)
    }

    private func circularCountdownText(_ milestone: MilestoneSnapshotItem) -> String {
        let text = countdownText(milestone)
        if text == "今天" { return "今" }
        if text == "明天" { return "明" }
        if text == "即将开始" { return "到" }
        if text == "已到期" || text == "已过期" { return "完" }
        return text
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                Color(red: 0.988, green: 0.968, blue: 0.929)
            }
        } else {
            background(Color(red: 0.988, green: 0.968, blue: 0.929))
        }
    }
}

struct MilestoneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.yili.almanac.milestone",
            provider: MilestoneWidgetProvider()
        ) { entry in
            MilestoneWidgetView(entry: entry)
        }
        .configurationDisplayName("宜历倒计时")
        .description("显示最近的里程碑和倒计时。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

@main
struct AlmanacMilestoneWidgetBundle: WidgetBundle {
    var body: some Widget {
        MilestoneWidget()
    }
}
