import Foundation

struct User: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var displayName: String
    var avatarURL: URL?
    /// Compressed JPEG stored as base64 when Firebase Storage is unavailable (Spark plan).
    var avatarBase64: String?
    var interests: [String]
    var ageConfirmedAt: Date?
}
