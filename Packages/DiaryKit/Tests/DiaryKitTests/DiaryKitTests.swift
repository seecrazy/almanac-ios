import XCTest
import CryptoKit
@testable import DiaryKit

final class DiaryKitTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeEntry(
        date: Date,
        body: String = "今天完成了日记存储。",
        mood: DiaryMood? = .good
    ) -> DiaryEntry {
        DiaryEntry(
            date: date,
            mood: mood,
            body: body,
            skeleton: [
                DiarySkeletonItem(
                    title: "产品评审",
                    timeText: "14:00–15:00",
                    calendarTitle: "工作",
                    isAllDay: false
                )
            ],
            createdAt: date,
            updatedAt: date,
            calendar: calendar
        )
    }

    func testSaveFindUpdateAndDeleteSameDay() throws {
        let (store, _) = try makeStore()
        let day = date(2026, 11, 5)
        var entry = makeEntry(date: day)

        try store.save(entry, calendar: calendar)
        XCTAssertEqual(try store.entry(on: day, calendar: calendar), entry)
        XCTAssertEqual(store.recordCount, 1)

        entry.body = "补充了下午的会议感受。"
        entry.mood = .tired
        entry.updatedAt = date(2026, 11, 5, hour: 22)
        try store.save(entry, calendar: calendar)

        let saved = try store.entry(on: day, calendar: calendar)
        XCTAssertEqual(saved, entry)
        XCTAssertEqual(saved?.body, "补充了下午的会议感受。")
        XCTAssertEqual(saved?.mood, .tired)
        XCTAssertEqual(store.recordCount, 1)

        try store.delete(on: day, calendar: calendar)
        XCTAssertNil(try store.entry(on: day, calendar: calendar))
        XCTAssertEqual(store.recordCount, 0)
    }

    func testEncryptedDatabaseDoesNotContainPlaintext() throws {
        let (store, databaseURL) = try makeStore()
        let day = date(2026, 11, 5)
        try store.save(makeEntry(date: day), calendar: calendar)

        let databaseData = try Data(contentsOf: databaseURL)
        XCTAssertFalse(databaseData.contains("今天完成".data(using: .utf8)!))
        XCTAssertFalse(databaseData.contains("产品评审".data(using: .utf8)!))
        XCTAssertFalse(databaseData.contains("2026-11-05".data(using: .utf8)!))
        XCTAssertEqual(store.recordCount, 1)
    }

    func testWrongKeyCannotFindEntryAndCannotDecryptPayload() throws {
        let (store, databaseURL) = try makeStore()
        let day = date(2026, 11, 5)
        try store.save(makeEntry(date: day), calendar: calendar)

        let wrongStore = try DiaryStore(databaseURL: databaseURL, key: SymmetricKey(size: .bits256))
        XCTAssertNil(try wrongStore.entry(on: day, calendar: calendar))
        XCTAssertEqual(try wrongStore.allEntries(calendar: calendar).count, 0)
        XCTAssertEqual(try store.allEntries(calendar: calendar).count, 1)

        let plaintext = "私密内容".data(using: .utf8)!
        let correctKey = SymmetricKey(size: .bits256)
        let ciphertext = try DiaryCrypto.encrypt(plaintext, key: correctKey)
        XCTAssertThrowsError(try DiaryCrypto.decrypt(ciphertext, key: SymmetricKey(size: .bits256))) { error in
            XCTAssertEqual(error as? DiaryCryptoError, .decryptionFailed)
        }
        XCTAssertEqual(try DiaryCrypto.decrypt(ciphertext, key: correctKey), plaintext)
    }

    func testCannotSaveBlankEntryOrOversizedBody() throws {
        let (store, _) = try makeStore()
        XCTAssertThrowsError(try store.save(makeEntry(date: date(2026, 11, 5), body: "   ", mood: nil), calendar: calendar))

        let oversized = makeEntry(
            date: date(2026, 11, 5),
            body: String(repeating: "长", count: DiaryEntry.maximumBodyLength + 1)
        )
        XCTAssertThrowsError(try store.save(oversized, calendar: calendar))
        XCTAssertEqual(store.recordCount, 0)
    }

    func testDayKeyIsStableAcrossDifferentTimes() {
        let first = DiaryCrypto.dayKey(for: date(2026, 11, 5, hour: 1), calendar: calendar)
        let second = DiaryCrypto.dayKey(for: date(2026, 11, 5, hour: 23), calendar: calendar)
        XCTAssertEqual(first, "2026-11-05")
        XCTAssertEqual(first, second)
    }

    func testSkeletonIdentifiableAndCodableRoundTrip() throws {
        let item = DiarySkeletonItem(title: "会议", timeText: "09:00–10:00", calendarTitle: "工作", isAllDay: false)
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([DiarySkeletonItem].self, from: data)
        XCTAssertEqual(decoded, [item])
        XCTAssertEqual(item.id, "09:00–10:00|工作|会议|timed")
    }

    private func databaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DiaryKitTests-\(UUID().uuidString)")
            .appendingPathComponent("diary.sqlite")
    }

    private func makeStore(url: URL? = nil) throws -> (DiaryStore, URL) {
        let url = url ?? databaseURL()
        let store = try DiaryStore(databaseURL: url, key: SymmetricKey(size: .bits256))
        return (store, url)
    }
}
