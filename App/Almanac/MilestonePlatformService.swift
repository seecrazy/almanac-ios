import Foundation
import MilestoneKit
import UserNotifications

enum MilestoneNotificationAuthorizationState: Equatable {
    case notDetermined
    case granted
    case denied
}

final class MilestonePlatformService {
    private static let identifierPrefix = "milestone."

    private let notificationCenter = UNUserNotificationCenter.current()
    private let fileManager = FileManager.default

    func authorizationStatus() async -> MilestoneNotificationAuthorizationState {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    func requestAuthorizationIfNeeded() async -> MilestoneNotificationAuthorizationState {
        let state = await authorizationStatus()
        guard state == .notDetermined else { return state }

        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    func sync(
        milestones: [Milestone],
        anniversaries: [Anniversary] = [],
        referenceDate: Date,
        shouldRequestAuthorization: Bool
    ) async -> (authorization: MilestoneNotificationAuthorizationState, snapshotAvailable: Bool) {
        let snapshotItems = milestones.map { milestone in
            MilestoneSnapshotItem(
                id: milestone.id,
                title: milestone.title,
                targetDate: milestone.targetDate,
                isAllDay: milestone.isAllDay,
                category: milestone.category.rawValue
            )
        }
        let snapshot = MilestoneSnapshotBuilder.make(
            milestones: snapshotItems,
            generatedAt: referenceDate
        )
        let snapshotAvailable = writeSnapshot(snapshot)

        let authorization: MilestoneNotificationAuthorizationState
        if shouldRequestAuthorization {
            authorization = await self.requestAuthorizationIfNeeded()
        } else {
            authorization = await authorizationStatus()
        }

        guard authorization == .granted else {
            await removePendingMilestoneNotifications()
            return (authorization, snapshotAvailable)
        }

        let requests = milestones.flatMap { milestone in
            MilestoneNotificationPlanner.requests(
                milestoneID: milestone.id,
                title: milestone.title,
                targetDate: milestone.targetDate,
                isAllDay: milestone.isAllDay,
                reminders: milestone.reminders,
                referenceDate: referenceDate
            )
        }

        let anniversaryRequests = anniversaries.flatMap { anniversary -> [MilestoneNotificationRequest] in
            guard let occurrence = AnniversaryResolver.nextOccurrence(
                for: anniversary,
                onOrAfter: referenceDate
            ) else { return [] }

            return MilestoneNotificationPlanner.requests(
                milestoneID: anniversary.id,
                title: anniversary.notificationTitle,
                targetDate: occurrence.date,
                isAllDay: true,
                reminders: anniversary.reminders,
                referenceDate: referenceDate,
                notificationTitle: "生日 / 纪念日"
            )
        }

        let allRequests = requests + anniversaryRequests

        await removePendingMilestoneNotifications()
        for request in allRequests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.subtitle = request.subtitle
            content.body = request.body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, request.fireDate.timeIntervalSince(referenceDate)),
                repeats: false
            )
            let notificationRequest = UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: trigger
            )
            _ = try? await notificationCenter.add(notificationRequest)
        }

        return (authorization, snapshotAvailable)
    }

    private func removePendingMilestoneNotifications() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func readSnapshot() -> MilestoneSnapshot? {
        guard let url = snapshotURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(MilestoneSnapshot.self, from: data)
    }

    func writeSnapshot(_ snapshot: MilestoneSnapshot) -> Bool {
        guard let url = snapshotURL() else { return false }

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

    private func snapshotURL() -> URL? {
        guard let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: MilestoneSnapshotStorage.appGroupIdentifier
        ) else {
            return nil
        }

        let directory = container.appendingPathComponent("Widgets", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(MilestoneSnapshotStorage.fileName)
    }
}
