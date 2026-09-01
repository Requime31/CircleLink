import Foundation

struct ValidatedCommunityContent: Equatable, Sendable {
    let name: String
    let description: String
}

enum CommunityContentValidationError: LocalizedError, Equatable, Sendable {
    case nameRequired
    case nameTooLong
    case descriptionTooLong

    var errorDescription: String? {
        switch self {
        case .nameRequired:
            return "Enter a community name."
        case .nameTooLong:
            return "Name must be \(CommunityContentPolicy.nameLimit) characters or fewer."
        case .descriptionTooLong:
            return "Description must be \(CommunityContentPolicy.descriptionLimit) characters or fewer."
        }
    }
}

/// Shared input and presentation policy. `String.count` is Unicode-grapheme aware.
enum CommunityContentPolicy {
    static let nameLimit = 30
    static let descriptionLimit = 500

    /// Bounds oversized pastes while retaining enough text to keep the draft visibly invalid.
    static let nameDraftSafetyLimit = nameLimit * 4
    static let descriptionDraftSafetyLimit = descriptionLimit * 4

    static func validate(name: String, description: String) throws -> ValidatedCommunityContent {
        let normalizedName = trimmed(name)
        let normalizedDescription = trimmed(description)

        guard !normalizedName.isEmpty else {
            throw CommunityContentValidationError.nameRequired
        }
        guard normalizedName.count <= nameLimit else {
            throw CommunityContentValidationError.nameTooLong
        }
        guard normalizedDescription.count <= descriptionLimit else {
            throw CommunityContentValidationError.descriptionTooLong
        }

        return ValidatedCommunityContent(
            name: normalizedName,
            description: normalizedDescription
        )
    }

    static func boundedNameDraft(_ value: String) -> String {
        String(value.prefix(nameDraftSafetyLimit))
    }

    static func boundedDescriptionDraft(_ value: String) -> String {
        String(value.prefix(descriptionDraftSafetyLimit))
    }

    /// Compact title for navigation/chat chrome. The original model remains untouched.
    static func safeDisplayName(
        _ value: String,
        fallback: String = "Community",
        limit: Int = nameLimit
    ) -> String {
        let normalized = trimmed(value)
        guard !normalized.isEmpty else { return fallback }
        let safeLimit = max(limit, 2)
        guard normalized.count > safeLimit else { return normalized }
        return String(normalized.prefix(safeLimit - 1)) + "…"
    }

    static func displayDescription(_ value: String) -> String {
        trimmed(value)
    }

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
