import CryptoKit
import Foundation

public enum DiaryCryptoError: Error, Equatable {
    case encryptionFailed
    case decryptionFailed
    case invalidPayload
}

public enum DiaryCrypto {
    public static func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        guard key.bitCount > 0 else { throw DiaryCryptoError.encryptionFailed }
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw DiaryCryptoError.encryptionFailed
        }
        return combined
    }

    public static func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data {
        guard key.bitCount > 0 else { throw DiaryCryptoError.decryptionFailed }
        guard let box = try? AES.GCM.SealedBox(combined: ciphertext) else {
            throw DiaryCryptoError.decryptionFailed
        }
        guard let plaintext = try? AES.GCM.open(box, using: key) else {
            throw DiaryCryptoError.decryptionFailed
        }
        return plaintext
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        var normalized = calendar
        normalized.timeZone = calendar.timeZone
        let components = normalized.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1900
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func databaseDayKey(for date: Date, key: SymmetricKey, calendar: Calendar = .current) -> Data {
        let dayKey = Self.dayKey(for: date, calendar: calendar).data(using: .utf8) ?? Data()
        let code = HMAC<SHA256>.authenticationCode(for: dayKey, using: key)
        return Data(code)
    }
}
