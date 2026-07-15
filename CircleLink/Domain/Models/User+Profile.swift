import Foundation

extension User {
    static let minInterests = 3
    static let maxInterests = 5

    /// Profile setup is complete when display name and 3–5 interests are set (Phase 3).
    var isProfileComplete: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && interests.count >= Self.minInterests
            && interests.count <= Self.maxInterests
    }
}
