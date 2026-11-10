import Foundation
import MilestoneKit
import SwiftUI
import WidgetKit

struct ScheduleWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ScheduleWidgetSnapshot?
}

struct ScheduleSnapshotReader {
    func read() -> ScheduleWidgetSnapshot? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ScheduleWidgetSnapshotStorage.appGroupIdentifier
        ) else {
            return nil
        }

        let url = container
            .appendingPathComponent("Widgets", isDirectory: true)
            .appendingPathComponent(ScheduleWidgetSnapshotStorage.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ScheduleWidgetSnapshot.self, from: data)
    }
}

struct ScheduleWidgetProvider: TimelineProvider {
    private let reader = ScheduleSnapshotReader()

    func placeholder(in context: Context) -> ScheduleWidgetEntry {
        ScheduleWidgetEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (ScheduleWidgetEntry) -> Void
    ) {
        completion(entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ScheduleWidgetEntry>) -> Void
    ) {
        let currentEntry = entry()
        completion(Timeline(
            entries: [currentEntry],
            policy: .after(nextRefreshDate(after: currentEntry.date, snapshot: currentEntry.snapshot))
        ))
    }

    private func entry() -> ScheduleWidgetEntry {
        ScheduleWidgetEntry(date: Date(), snapshot: reader.read())
    }

    private func nextRefreshDate(after date: Date, snapshot: ScheduleWidgetSnapshot?) -> Date {
        let calendar = Calendar.current
        let regularRefresh = date.addingTimeInterval(15 * 60)
        let nextDay = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: date) ?? date
        )

        let boundaries = (snapshot?.events ?? [])
            .filter { $0.startDate > date || $0.endDate > date }
            .flatMap { [$0.startDate, $0.endDate] }
            .filter { $0 > date }
            .map { $0.addingTimeInterval(60) }

        return min(regularRefresh, nextDay, boundaries.min() ?? regularRefresh)
    }
}

private extension DateFormatter {
    static let scheduleHHmm: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let scheduleMonthDayWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
}

struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ScheduleWidgetEntry

    var body: some View {
        familyContent
            .widgetBackground()
            .widgetURL(URL(string: "almanac://calendar"))
    }

    @ViewBuilder
    private var familyContent: some View {
        switch family {
        case .accessoryInline:
            inlineContent
        case .accessoryRectangular:
            rectangularContent
        default:
            systemContent
        }
    }

    // MARK: 桌面 Widget

    @ViewBuilder
    private var systemContent: some View {
        if let snapshot = entry.snapshot, isSnapshotForToday(snapshot) {
            if snapshot.events.isEmpty {
                emptyDayView
            } else if family == .systemSmall {
                smallContent(snapshot: snapshot)
            } else {
                mediumContent(snapshot: snapshot)
            }
        } else {
            missingSnapshotView
        }
    }

    private func smallContent(snapshot: ScheduleWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatter.scheduleMonthDayWeekday.string(from: snapshot.day))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let event = snapshot.events.first {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(timeText(event))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
            if snapshot.events.count > 1 {
                Text("共 \(snapshot.events.count) 项日程")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tint(eventColor(snapshot.events.first))
    }

    private func mediumContent(snapshot: ScheduleWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(DateFormatter.scheduleMonthDayWeekday.string(from: snapshot.day))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.events.count) 项日程")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            ForEach(snapshot.events.prefix(4)) { event in
                HStack(spacing: 7) {
                    Circle()
                        .fill(eventColor(event))
                        .frame(width: 5, height: 5)
                    Text(timeText(event))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                        .lineLimit(1)
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyDayView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatter.scheduleMonthDayWeekday.string(from: entry.snapshot?.day ?? entry.date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("今天暂无日程")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
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

    // MARK: 锁屏 Widget

    private var inlineContent: some View {
        if let event = entry.snapshot?.events.first(where: { !$0.isAllDay }) {
            Text("下一条 · \(event.title) \(DateFormatter.scheduleHHmm.string(from: event.startDate))")
        } else if let event = entry.snapshot?.events.first {
            Text("今天 · \(event.title)")
        } else {
            Text("今天暂无日程")
        }
    }

    @ViewBuilder
    private var rectangularContent: some View {
        if let snapshot = entry.snapshot, !snapshot.events.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText(snapshot.events[0]))
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
                Text(snapshot.events[0].title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                if snapshot.events.count > 1 {
                    Text("之后 \(snapshot.events.count - 1) 项")
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
            }
        } else {
            Text("今天暂无日程")
                .font(.system(size: 12))
        }
    }

    // MARK: 工具

    private func isSnapshotForToday(_ snapshot: ScheduleWidgetSnapshot) -> Bool {
        Calendar.current.isDateInToday(snapshot.day)
    }

    private func timeText(_ event: ScheduleWidgetEventItem) -> String {
        if event.isAllDay { return "全天" }
        return "\(DateFormatter.scheduleHHmm.string(from: event.startDate))–\(DateFormatter.scheduleHHmm.string(from: event.endDate))"
    }

    private func eventColor(_ event: ScheduleWidgetEventItem?) -> Color {
        guard let rgba = event?.colorRGBA, rgba.count >= 3 else {
            return Color(red: 0.710, green: 0.537, blue: 0.235)
        }
        let opacity = rgba.count >= 4 ? rgba[3] : 1
        return Color(red: rgba[0], green: rgba[1], blue: rgba[2], opacity: opacity)
    }
}

struct ScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.yili.almanac.schedule",
            provider: ScheduleWidgetProvider()
        ) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("宜历日程")
        .description("显示今天的日程安排与下一条日程。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}
