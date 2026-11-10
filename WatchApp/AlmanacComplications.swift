import MilestoneKit
import SwiftUI
import WidgetKit

// 表盘复杂功能（staging，未接入任何 target —— 随 Watch target 一起启用）。
// 三个 accessory 族复用同一快照；无快照时显示占位。

struct WatchBriefingEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchBriefingSnapshot?
}

struct WatchBriefingProvider: TimelineProvider {
    private let reader = WatchBriefingSnapshotReader()

    func placeholder(in context: Context) -> WatchBriefingEntry {
        WatchBriefingEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchBriefingEntry) -> Void) {
        completion(WatchBriefingEntry(date: Date(), snapshot: reader.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchBriefingEntry>) -> Void) {
        let entry = WatchBriefingEntry(date: Date(), snapshot: reader.read())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

struct AlmanacComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.yili.almanac.watch.complication", provider: WatchBriefingProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("宜历今日")
        .description("农历、节气与下一个重要日子。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WatchBriefingEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryCircular:
            ZStack {
                Circle().stroke(.secondary.opacity(0.4))
                Text("宜")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.snapshot?.lunarText ?? "打开宜历")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if let term = entry.snapshot?.solarTermText ?? entry.snapshot?.festivalText {
                    Text(term).font(.system(size: 10)).opacity(0.7)
                }
            }
        }
    }

    private var inlineText: String {
        if let snapshot = entry.snapshot {
            return snapshot.lunarText + (snapshot.solarTermText.map { " · \($0)" } ?? "")
        }
        return "打开宜历更新数据"
    }
}
