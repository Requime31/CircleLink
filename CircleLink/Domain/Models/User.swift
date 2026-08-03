import Foundation

/// Domain entity — must stay off the default `@MainActor` isolation so
/// `Equatable` / `Sendable` work in repositories and background tasks.
nonisolated struct User: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var displayName: String
    var avatarURL: URL?
    /// Persistence leftover from Firestore Spark avatar storage.
    /// Data owns encode/decode via `FirestoreUserDocument`; Domain still mirrors the field
    /// so Profile/Connect UI keep working. A future option-B phase would move media off Domain.
    var avatarBase64: String?
    var interests: [String]
    var ageConfirmedAt: Date?
}
