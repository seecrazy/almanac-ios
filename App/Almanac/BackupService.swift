import Foundation
import HolidayData
import MilestoneKit

/// 备份文档 v1：里程碑 / 纪念日 / 闹钟（含工作日模板）。
/// 日记为 AES-256-GCM 加密且密钥在 Keychain，跨设备恢复属 SyncProvider 范畴，明确不在 v0。
struct BackupDocument: Codable {
    static let version = 1

    let version: Int
    let exportedAt: Date
    let milestones: [Milestone]
    let anniversaries: [Anniversary]
    let alarmTemplate: WorkdayTemplate
    let alarms: [WorkdayAlarm]
}

enum BackupService {
    enum BackupError: LocalizedError {
        case unreadable
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "备份文件无法读取（损坏或格式不符）"
            case .unsupportedVersion(let version):
                return "备份版本 \(version) 暂不支持"
            }
        }
    }

    struct ImportPreview {
        let newMilestones: [Milestone]
        let newAnniversaries: [Anniversary]
        let newAlarms: [WorkdayAlarm]
        let template: WorkdayTemplate?
    }

    static func export(
        milestones: [Milestone],
        anniversaries: [Anniversary],
        alarmTemplate: WorkdayTemplate,
        alarms: [WorkdayAlarm]
    ) throws -> Data {
        let document = BackupDocument(
            version: BackupDocument.version,
            exportedAt: Date(),
            milestones: milestones,
            anniversaries: anniversaries,
            alarmTemplate: alarmTemplate,
            alarms: alarms
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    static func decode(_ data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(BackupDocument.self, from: data) else {
            throw BackupError.unreadable
        }
        guard document.version <= BackupDocument.version else {
            throw BackupError.unsupportedVersion(document.version)
        }
        return document
    }

    /// 按 id 去重计算导入增量。
    static func preview(
        _ document: BackupDocument,
        existingMilestones: [Milestone],
        existingAnniversaries: [Anniversary],
        existingAlarms: [WorkdayAlarm]
    ) -> ImportPreview {
        let milestoneIDs = Set(existingMilestones.map(\.id))
        let anniversaryIDs = Set(existingAnniversaries.map(\.id))
        let alarmIDs = Set(existingAlarms.map(\.id))

        let hasContent = !document.milestones.isEmpty || !document.anniversaries.isEmpty || !document.alarms.isEmpty
        return ImportPreview(
            newMilestones: document.milestones.filter { !milestoneIDs.contains($0.id) },
            newAnniversaries: document.anniversaries.filter { !anniversaryIDs.contains($0.id) },
            newAlarms: document.alarms.filter { !alarmIDs.contains($0.id) },
            template: hasContent ? document.alarmTemplate : nil
        )
    }

    static func fileName() -> String {
        "宜历备份-\(AppFormatters.alarmIdentifierDate.string(from: Date())).json"
    }
}
