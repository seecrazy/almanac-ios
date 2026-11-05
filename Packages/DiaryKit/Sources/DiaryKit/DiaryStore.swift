import Foundation
import CryptoKit
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DiaryStoreError: Error, Equatable {
    case openFailed(String)
    case sqliteError(String)
    case encryptionFailed
    case decryptionFailed
    case invalidEntry
    case invalidPayload
}

public final class DiaryStore: @unchecked Sendable {
    private let database: OpaquePointer?
    private let key: SymmetricKey

    public init(databaseURL: URL, key: SymmetricKey) throws {
        guard key.bitCount == 256 else {
            throw DiaryStoreError.encryptionFailed
        }

        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            databaseURL.path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK else {
            if let handle { sqlite3_close(handle) }
            throw DiaryStoreError.openFailed(String(cString: sqlite3_errstr(result)))
        }

        self.database = handle
        self.key = key
        try execute("PRAGMA busy_timeout = 2000")
        try execute("PRAGMA journal_mode = WAL")
        try execute("""
        CREATE TABLE IF NOT EXISTS diary_entries (
            day_key BLOB PRIMARY KEY,
            payload BLOB NOT NULL
        ) WITHOUT ROWID
        """)
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    public func save(_ entry: DiaryEntry, calendar: Calendar = .current) throws {
        guard entry.canSave else { throw DiaryStoreError.invalidEntry }
        let normalized = entry.normalized(calendar: calendar)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let plaintext: Data
        do {
            plaintext = try encoder.encode(normalized)
        } catch {
            throw DiaryStoreError.invalidEntry
        }

        let payload: Data
        do {
            payload = try DiaryCrypto.encrypt(plaintext, key: key)
        } catch {
            throw DiaryStoreError.encryptionFailed
        }

        let statement = try prepare("""
        INSERT INTO diary_entries(day_key, payload)
        VALUES (?, ?)
        ON CONFLICT(day_key) DO UPDATE SET payload = excluded.payload
        """)
        defer { sqlite3_finalize(statement) }
        let dayKey = DiaryCrypto.databaseDayKey(for: normalized.date, key: key, calendar: calendar)
        try bindData([dayKey, payload], to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DiaryStoreError.sqliteError(lastErrorMessage)
        }
    }

    public func entry(on date: Date, calendar: Calendar = .current) throws -> DiaryEntry? {
        let statement = try prepare("SELECT payload FROM diary_entries WHERE day_key = ?")
        defer { sqlite3_finalize(statement) }
        let dayKey = DiaryCrypto.databaseDayKey(for: date, key: key, calendar: calendar)
        try bindData([dayKey], to: statement)
        let stepResult = sqlite3_step(statement)
        if stepResult == SQLITE_DONE { return nil }
        guard stepResult == SQLITE_ROW else {
            throw DiaryStoreError.sqliteError(lastErrorMessage)
        }
        return try decodeEntry(sqlite3_column_blob(statement, 0), length: sqlite3_column_bytes(statement, 0))
    }

    public func entries(on dates: [Date], calendar: Calendar = .current) throws -> [DiaryEntry] {
        try dates.compactMap { try entry(on: $0, calendar: calendar) }
    }

    public func allEntries(calendar: Calendar = .current) throws -> [DiaryEntry] {
        let statement = try prepare("SELECT payload FROM diary_entries")
        defer { sqlite3_finalize(statement) }

        var entries: [DiaryEntry] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else {
                throw DiaryStoreError.sqliteError(lastErrorMessage)
            }
            if let entry = try? decodeEntry(
                sqlite3_column_blob(statement, 0),
                length: sqlite3_column_bytes(statement, 0)
            ) {
                entries.append(entry)
            }
        }
        return entries.sorted { $0.date > $1.date }
    }

    public func delete(on date: Date, calendar: Calendar = .current) throws {
        let statement = try prepare("DELETE FROM diary_entries WHERE day_key = ?")
        defer { sqlite3_finalize(statement) }
        let dayKey = DiaryCrypto.databaseDayKey(for: date, key: key, calendar: calendar)
        try bindData([dayKey], to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DiaryStoreError.sqliteError(lastErrorMessage)
        }
    }

    public var recordCount: Int {
        guard let statement = try? prepare("SELECT COUNT(*) FROM diary_entries") else { return 0 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func decodeEntry(_ bytes: UnsafeRawPointer?, length: Int32) throws -> DiaryEntry {
        guard let bytes, length > 0 else { throw DiaryStoreError.decryptionFailed }
        let ciphertext = Data(bytes: bytes, count: Int(length))
        let plaintext: Data
        do {
            plaintext = try DiaryCrypto.decrypt(ciphertext, key: key)
        } catch {
            throw DiaryStoreError.decryptionFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        do {
            return try decoder.decode(DiaryEntry.self, from: plaintext)
        } catch {
            throw DiaryStoreError.invalidPayload
        }
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorPointer)
        let message = errorPointer.map { String(cString: $0) } ?? ""
        if let errorPointer { sqlite3_free(errorPointer) }
        guard result == SQLITE_OK else {
            throw DiaryStoreError.sqliteError(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw DiaryStoreError.sqliteError(lastErrorMessage)
        }
        return statement
    }

    private func bindData(_ values: [Data], to statement: OpaquePointer) throws {
        for (index, value) in values.enumerated() {
            let result = value.withUnsafeBytes { rawBuffer -> Int32 in
                guard let address = rawBuffer.baseAddress else {
                    return SQLITE_OK
                }
                return sqlite3_bind_blob(
                    statement,
                    Int32(index + 1),
                    address,
                    Int32(value.count),
                    sqliteTransient
                )
            }
            guard result == SQLITE_OK else {
                throw DiaryStoreError.sqliteError(lastErrorMessage)
            }
        }
    }

    private var lastErrorMessage: String {
        guard let database else { return "database is not open" }
        return String(cString: sqlite3_errmsg(database))
    }
}
