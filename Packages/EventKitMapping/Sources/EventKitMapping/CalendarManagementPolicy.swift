import Foundation

public enum CalendarNameValidationError: Error, Equatable {
    case empty
    case tooLong
}

public enum CalendarManagementPolicy {
    public static let maximumNameLength = 64

    public static func normalizedTitle(_ title: String) -> Result<String, CalendarNameValidationError> {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .failure(.empty) }
        guard normalized.count <= maximumNameLength else { return .failure(.tooLong) }
        return .success(normalized)
    }

    public static func canManageCalendar(
        isLocal: Bool,
        allowsContentModifications: Bool
    ) -> Bool {
        isLocal && allowsContentModifications
    }
}
