import Foundation
import MilestoneKit
import WidgetKit

extension EventStoreService {
    /// 把"今天"的可见日程写入 App Group 快照并刷新小组件。
    /// loadEvents 完成后与 App 激活时调用；快照可随时整体重写。
    func syncScheduleWidget(referenceDate: Date = Date()) {
        guard accessState == .granted else { return }

        let items = events(on: referenceDate).map { event in
            ScheduleWidgetEventItem(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                calendarTitle: event.calendarTitle,
                colorRGBA: event.calendarColor.map { [$0.red, $0.green, $0.blue, $0.opacity] }
            )
        }

        let snapshot = ScheduleWidgetSnapshotBuilder.make(
            items: items,
            for: referenceDate,
            generatedAt: referenceDate
        )

        if writeScheduleSnapshot(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func writeScheduleSnapshot(_ snapshot: ScheduleWidgetSnapshot) -> Bool {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ScheduleWidgetSnapshotStorage.appGroupIdentifier
        ) else {
            return false
        }

        let directory = container.appendingPathComponent("Widgets", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(ScheduleWidgetSnapshotStorage.fileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
