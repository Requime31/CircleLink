import Foundation

/// Domain entity — must stay off the default `@MainActor` isolation so
/// `Equatable` / `Sendable` work in repositories and background tasks.
nonisolated struct User: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var displayName: String
    var avatarURL: URL?
    /// Compressed JPEG stored as base64 when Firebase Storage is unavailable (Spark plan).
    var avatarBase64: String?
    var interests: [String]
    var ageConfirmedAt: Date?
}
