import Foundation

/// A post in a community feed (`communities/{communityId}/posts/{postId}`).
/// At least one of `text` / `imageURL` must be present (enforced in VM + rules).
nonisolated struct CommunityPost: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let communityId: String
    let authorId: String
    var text: String?
    var imageURL: URL?
    let createdAt: Date
}
