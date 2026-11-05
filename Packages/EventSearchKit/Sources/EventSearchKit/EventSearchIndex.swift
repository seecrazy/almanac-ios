import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

public struct IndexedEventRecord: Hashable, Sendable {
    public let eventID: String
    public let calendarID: String
    public let title: String
    public let location: String?
    public let notes: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool

    public init(
        eventID: String,
        calendarID: String,
        title: String,
        location: String?,
        notes: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) {
        self.eventID = eventID
        self.calendarID = calendarID
        self.title = title
        self.location = location
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
    }
}

public final class EventSearchIndex: @unchecked Sendable {
    public static let resultLimit = 200

    private let database: OpaquePointer

    public init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var handle: OpaquePointer?
        let openResult = sqlite3_open_v2(
            databaseURL.path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database = handle else {
            if let handle { sqlite3_close(handle) }
            throw EventSearchIndexError.openFailed(
                String(cString: sqlite3_errstr(openResult))
            )
        }

        self.database = database
        try execute("PRAGMA busy_timeout = 2000")
        try execute("PRAGMA journal_mode = WAL")
        try execute("""
        CREATE TABLE IF NOT EXISTS event_metadata (
            event_id TEXT PRIMARY KEY,
            calendar_id TEXT NOT NULL,
            start_time REAL NOT NULL,
            end_time REAL NOT NULL,
            is_all_day INTEGER NOT NULL
        ) WITHOUT ROWID
        """)
        try execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS event_fts USING fts5(
            event_id UNINDEXED,
            title,
            location,
            notes,
            tokenize='unicode61'
        )
        """)
        try execute("""
        CREATE INDEX IF NOT EXISTS event_metadata_start_time
        ON event_metadata(start_time, end_time)
        """)
    }

    deinit {
        sqlite3_close(database)
    }

    public func replaceAll(_ records: [IndexedEventRecord]) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("DELETE FROM event_fts")
            try execute("DELETE FROM event_metadata")
            try insert(records)
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    public func search(
        keyword: String,
        interval: DateInterval,
        calendarIDs: Set<String>?,
        includeAllDay: Bool,
        limit: Int = EventSearchIndex.resultLimit
    ) throws -> [IndexedEventRecord] {
        let matchExpression = Self.matchExpression(for: keyword)
        guard !matchExpression.isEmpty else { return [] }
        guard calendarIDs?.isEmpty != true else { return [] }
        let containsCJK = keyword.unicodeScalars.contains { scalar in
            (0x3400...0x9FFF).contains(scalar.value) ||
            (0xF900...0xFAFF).contains(scalar.value)
        }

        let matchingEventsSQL = containsCJK
            ? """
            SELECT event_id, title, location, notes
            FROM event_fts
            """
            : """
            SELECT event_id, title, location, notes
            FROM event_fts
            WHERE event_fts MATCH ?
            """
        var sql = """
        WITH matching_events AS (
            \(matchingEventsSQL)
        )
        SELECT m.event_id, m.calendar_id, m.start_time, m.end_time, m.is_all_day,
               f.title, f.location, f.notes
        FROM matching_events AS f
        JOIN event_metadata AS m ON m.event_id = f.event_id
        WHERE m.start_time < ? AND m.end_time > ?
        """
        var bindings: [BindingValue] = [
            .double(interval.end.timeIntervalSince1970),
            .double(interval.start.timeIntervalSince1970)
        ]
        if !containsCJK {
            bindings.insert(.text(matchExpression), at: 0)
        }
        if containsCJK {
            let likePattern = Self.likePattern(for: keyword)
            sql += """

            AND (
                f.title LIKE ? ESCAPE '\\' COLLATE NOCASE
                OR f.location LIKE ? ESCAPE '\\' COLLATE NOCASE
                OR f.notes LIKE ? ESCAPE '\\' COLLATE NOCASE
            )
            """
            bindings.append(contentsOf: [
                .text(likePattern),
                .text(likePattern),
                .text(likePattern)
            ])
        }

        if let calendarIDs {
            let placeholders = Array(repeating: "?", count: calendarIDs.count)
                .joined(separator: ", ")
            sql += " AND m.calendar_id IN (\(placeholders))"
            bindings.append(contentsOf: calendarIDs.sorted().map { .text($0) })
        }
        if !includeAllDay {
            sql += " AND m.is_all_day = 0"
        }

        sql += """

        ORDER BY m.start_time ASC, m.is_all_day DESC, m.end_time ASC
        LIMIT ?
        """
        bindings.append(.integer(max(0, limit)))

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var records: [IndexedEventRecord] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE { break }
            guard stepResult == SQLITE_ROW else {
                throw EventSearchIndexError.sqliteError(lastErrorMessage)
            }
            records.append(
                IndexedEventRecord(
                    eventID: columnText(statement, 0) ?? "",
                    calendarID: columnText(statement, 1) ?? "",
                    title: columnText(statement, 5) ?? "",
                    location: columnText(statement, 6),
                    notes: columnText(statement, 7),
                    startDate: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                    endDate: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                    isAllDay: sqlite3_column_int64(statement, 4) != 0
                )
            )
        }

        return records
    }

    public var recordCount: Int {
        guard let statement = try? prepare("SELECT COUNT(*) FROM event_metadata") else {
            return 0
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func insert(_ records: [IndexedEventRecord]) throws {
        let metadataStatement = try prepare("""
        INSERT INTO event_metadata(
            event_id, calendar_id, start_time, end_time, is_all_day
        ) VALUES (?, ?, ?, ?, ?)
        """)
        defer { sqlite3_finalize(metadataStatement) }

        let ftsStatement = try prepare("""
        INSERT INTO event_fts(event_id, title, location, notes)
        VALUES (?, ?, ?, ?)
        """)
        defer { sqlite3_finalize(ftsStatement) }

        for record in records {
            try bind([
                .text(record.eventID),
                .text(record.calendarID),
                .double(record.startDate.timeIntervalSince1970),
                .double(record.endDate.timeIntervalSince1970),
                .integer(record.isAllDay ? 1 : 0)
            ], to: metadataStatement)
            guard sqlite3_step(metadataStatement) == SQLITE_DONE else {
                throw EventSearchIndexError.sqliteError(lastErrorMessage)
            }
            sqlite3_reset(metadataStatement)
            sqlite3_clear_bindings(metadataStatement)

            try bind([
                .text(record.eventID),
                .text(record.title),
                .text(record.location ?? ""),
                .text(record.notes ?? "")
            ], to: ftsStatement)
            guard sqlite3_step(ftsStatement) == SQLITE_DONE else {
                throw EventSearchIndexError.sqliteError(lastErrorMessage)
            }
            sqlite3_reset(ftsStatement)
            sqlite3_clear_bindings(ftsStatement)
        }
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorPointer)
        let message = errorPointer.map { String(cString: $0) } ?? ""
        if let errorPointer { sqlite3_free(errorPointer) }
        guard result == SQLITE_OK else {
            throw EventSearchIndexError.sqliteError(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw EventSearchIndexError.sqliteError(lastErrorMessage)
        }
        return statement
    }

    private func bind(_ values: [BindingValue], to statement: OpaquePointer) throws {
        for (index, value) in values.enumerated() {
            let parameterIndex = Int32(index + 1)
            let result: Int32
            switch value {
            case .text(let text):
                result = sqlite3_bind_text(statement, parameterIndex, text, -1, sqliteTransient)
            case .double(let number):
                result = sqlite3_bind_double(statement, parameterIndex, number)
            case .integer(let number):
                result = sqlite3_bind_int64(statement, parameterIndex, Int64(number))
            }
            guard result == SQLITE_OK else {
                throw EventSearchIndexError.sqliteError(lastErrorMessage)
            }
        }
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_text(statement, index) != nil else { return nil }
        return String(cString: sqlite3_column_text(statement, index))
    }

    private var lastErrorMessage: String {
        String(cString: sqlite3_errmsg(database))
    }

    private static func matchExpression(for keyword: String) -> String {
        keyword
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { token in
                let escaped = token
                    .replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\" *"
            }
            .joined(separator: " ")
    }

    private static func likePattern(for keyword: String) -> String {
        let escaped = keyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }
}

private enum BindingValue {
    case text(String?)
    case double(Double)
    case integer(Int)
}

private enum EventSearchIndexError: Error {
    case openFailed(String)
    case sqliteError(String)
}
