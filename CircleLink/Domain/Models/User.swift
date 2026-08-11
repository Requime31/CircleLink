import Foundation

struct User: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var displayName: String
    var avatarURL: URL?
    /// Compressed JPEG stored as base64 when Firebase Storage is unavailable (Spark plan).
    var avatarBase64: String?
    var interests: [String]
    /// Public age shown on Connect / peer profiles. Optional for older profiles.
    var age: Int?
    /// Short “About Me” bio for Connect peer detail.
    var aboutMe: String
    var ageConfirmedAt: Date?

    init(
        id: String,
        displayName: String,
        avatarURL: URL? = nil,
        avatarBase64: String? = nil,
        interests: [String] = [],
        age: Int? = nil,
        aboutMe: String = "",
        ageConfirmedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.avatarBase64 = avatarBase64
        self.interests = interests
        self.age = age
        self.aboutMe = aboutMe
        self.ageConfirmedAt = ageConfirmedAt
    }

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
