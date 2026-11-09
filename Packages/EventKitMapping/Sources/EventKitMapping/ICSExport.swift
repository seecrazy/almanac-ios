import Foundation

/// 与 EventKit 无关的导出载荷，方便纯逻辑测试与复用。
public struct ICSEvent: Hashable, Sendable {
    public let uid: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?

    public init(
        uid: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String? = nil,
        notes: String? = nil
    ) {
        self.uid = uid
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
    }
}

/// RFC 5545 单事件导出。时刻事件用 UTC；全天事件用 VALUE=DATE。
public enum ICSExporter {
    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    public static func calendar(event: ICSEvent, timestamp: Date = Date(), timeZone: TimeZone = .current) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Yili//Almanac//CN",
            "CALSCALE:GREGORIAN",
            "BEGIN:VEVENT",
            "UID:\(escape(event.uid))",
            "DTSTAMP:\(stampFormatter.string(from: timestamp))",
            dateLine(name: "DTSTART", date: event.startDate, isAllDay: event.isAllDay, timeZone: timeZone),
            dateLine(name: "DTEND", date: event.endDate, isAllDay: event.isAllDay, timeZone: timeZone),
            "SUMMARY:\(escape(event.title))"
        ]
        if let location = event.location, !location.isEmpty {
            lines.append("LOCATION:\(escape(location))")
        }
        if let notes = event.notes, !notes.isEmpty {
            lines.append("DESCRIPTION:\(escape(notes))")
        }
        lines.append(contentsOf: ["END:VEVENT", "END:VCALENDAR"])
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// 生成可作文件名的安全标题。
    public static func fileNameTitle(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "日程" : String(trimmed.prefix(40))
    }

    private static func dateLine(name: String, date: Date, isAllDay: Bool, timeZone: TimeZone) -> String {
        if isAllDay {
            // 全天日期按事件所在时区归到"用户看到的日期"，不能用 UTC。
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyyMMdd"
            return "\(name);VALUE=DATE:\(formatter.string(from: date))"
        }
        return "\(name):\(stampFormatter.string(from: date))"
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }
}
