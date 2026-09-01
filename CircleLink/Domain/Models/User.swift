import Foundation

enum AccountState: String, Codable, Equatable, Sendable {
    case active
    case deactivated
}

enum AccountDeletionPolicy {
    nonisolated static let gracePeriodDays = 30
    nonisolated static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    nonisolated static func scheduledDeletionDate(from now: Date) -> Date? {
        calendar.date(byAdding: .day, value: gracePeriodDays, to: now)
    }
}

struct User: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var displayName: String
    var avatarURL: URL?
    /// Compressed JPEG stored as base64 when Firebase Storage is unavailable (Spark plan).
    var avatarBase64: String?
    var interests: [String]
    /// Owner-only birth date in canonical UTC-noon form. Convert before showing in a local DatePicker.
    /// Data implementations must not expose it in public profile DTOs.
    var birthDate: Date?
    /// Public age shown on Connect / peer profiles. Optional for older profiles.
    var age: Int?
    /// Short “About Me” bio for Connect peer detail.
    var aboutMe: String
    var ageConfirmedAt: Date?
    var accountState: AccountState
    var deletionRequestedAt: Date?
    var scheduledDeletionAt: Date?

    init(
        id: String,
        displayName: String,
        avatarURL: URL? = nil,
        avatarBase64: String? = nil,
        interests: [String] = [],
        birthDate: Date? = nil,
        age: Int? = nil,
        aboutMe: String = "",
        ageConfirmedAt: Date? = nil,
        accountState: AccountState = .active,
        deletionRequestedAt: Date? = nil,
        scheduledDeletionAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.avatarBase64 = avatarBase64
        self.interests = interests
        self.birthDate = birthDate
        self.age = age
        self.aboutMe = aboutMe
        self.ageConfirmedAt = ageConfirmedAt
        self.accountState = accountState
        self.deletionRequestedAt = deletionRequestedAt
        self.scheduledDeletionAt = scheduledDeletionAt
    }

    var isSociallyAvailable: Bool { accountState == .active }

    /// "Julian, 28" when age is known, otherwise just the name.
    var displayNameWithAge: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = name.isEmpty ? "Member" : name
        if let age {
            return "\(resolved), \(age)"
        }
        return resolved
    }
}
