import MilestoneKit
import SwiftUI

// Watch App（staging，未接入任何 target —— 按 WatchApp/README.md 的步骤在 Xcode GUI
// 创建 watchOS App target 后，把本目录文件加入该 target）。

@main
struct AlmanacWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchBriefingView()
        }
    }
}

struct WatchBriefingSnapshotReader {
    func read() -> WatchBriefingSnapshot? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WatchBriefingStorage.appGroupIdentifier
        ) else {
            return nil
        }
        let url = container
            .appendingPathComponent("Widgets", isDirectory: true)
            .appendingPathComponent(WatchBriefingStorage.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WatchBriefingSnapshot.self, from: data)
    }
}

/// 今日一瞥：农历 / 节气节日 / 宜忌 / 下一个里程碑 / 下一次闹钟 / 今日日程数。
struct WatchBriefingView: View {
    private let reader = WatchBriefingSnapshotReader()
    @State private var snapshot: WatchBriefingSnapshot?
    @State private var now = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let snapshot {
                    Text(now, format: .dateTime.month().day().weekday())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(snapshot.lunarText)
                        .font(.system(size: 15, weight: .medium))

                    if let festival = snapshot.festivalText {
                        Text(festival).font(.system(size: 13)).foregroundStyle(.red)
                    }
                    if let term = snapshot.solarTermText {
                        Text(term).font(.system(size: 13)).foregroundStyle(.green)
                    }
                    if let suitable = snapshot.suitableText {
                        Text(suitable).font(.system(size: 13))
                    }
                    if let avoid = snapshot.avoidText {
                        Text(avoid).font(.system(size: 13)).foregroundStyle(.secondary)
                    }

                    Divider()

                    if let title = snapshot.nextMilestoneTitle, let target = snapshot.nextMilestoneDate {
                        row(icon: "hourglass", title: title, detail: countdownText(target))
                    }
                    if let alarm = snapshot.nextAlarmName, let fire = snapshot.nextAlarmFireDate {
                        row(icon: "alarm", title: alarm, detail: fire.formatted(.dateTime.month().day().hour().minute()))
                    }
                    row(icon: "calendar", title: "\(snapshot.todayEventCount) 项日程", detail: "今天")
                } else {
                    Text("打开 iPhone 上的宜历更新数据")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            snapshot = reader.read()
            now = Date()
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func countdownText(_ target: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: now),
            to: Calendar.current.startOfDay(for: target)
        ).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "明天" }
        return days > 0 ? "\(days) 天后" : "已过期"
    }
}
