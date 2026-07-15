import Foundation

struct User: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var displayName: String
    var avatarURL: URL?
    var interests: [String]
    var ageConfirmedAt: Date?
}
