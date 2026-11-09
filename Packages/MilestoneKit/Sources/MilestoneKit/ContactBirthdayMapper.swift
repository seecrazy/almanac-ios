import Foundation

/// 通讯录生日候选（App 层从 CNContact 转换而来，包内不依赖 Contacts）。
public struct ContactBirthdayCandidate: Hashable, Sendable {
    public let contactID: String
    public let displayName: String
    public let month: Int
    public let day: Int
    /// iOS 允许"无年份生日"；nil 表示未知。
    public let year: Int?

    public init(contactID: String, displayName: String, month: Int, day: Int, year: Int?) {
        self.contactID = contactID
        self.displayName = displayName
        self.month = month
        self.day = day
        self.year = year
    }
}

public enum ContactBirthdayMapper {
    /// notes 中携带的来源标记，用于重复导入去重。
    public static let sourceNotePrefix = "contact:"

    /// 映射为生日 Anniversary；日期非法（月不在 1–12、日不在该月范围内）返回 nil。
    /// 无年份生日不计算年龄（showAge = false）。
    public static func anniversary(
        for candidate: ContactBirthdayCandidate,
        existing: [Anniversary] = [],
        createdAt: Date = Date()
    ) -> Anniversary? {
        guard (1...12).contains(candidate.month) else { return nil }
        var validator = Calendar(identifier: .gregorian)
        validator.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        guard let range = validator.range(
            of: .day,
            in: .month,
            for: validator.date(from: DateComponents(year: 2024, month: candidate.month))!
        ), range.contains(candidate.day) else {
            return nil
        }

        guard !isImported(contactID: candidate.contactID, existing: existing) else { return nil }

        var solarDate = DateComponents()
        solarDate.month = candidate.month
        solarDate.day = candidate.day

        // 2 月 29 无年份生日按平年处理（resolver 自行回退），仍允许导入。
        if let year = candidate.year, year >= 1901 {
            solarDate.year = year
        }

        return Anniversary(
            title: "\(candidate.displayName)的生日",
            personName: candidate.displayName,
            kind: .birthday,
            calendar: .solar,
            solarDate: solarDate,
            showAge: (candidate.year ?? 0) >= 1901,
            notes: "\(sourceNotePrefix)\(candidate.contactID)",
            createdAt: createdAt
        )
    }

    /// 已导入过的联系人（notes 含 contactID 标记）跳过。
    public static func isImported(contactID: String, existing: [Anniversary]) -> Bool {
        existing.contains { $0.notes == "\(sourceNotePrefix)\(contactID)" }
    }
}
