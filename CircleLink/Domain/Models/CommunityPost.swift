import Foundation

/// A post in a community feed (`communities/{communityId}/posts/{postId}`).
/// At least one of `text` / `imageURL` must be present (enforced in VM + rules).
struct CommunityPost: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let communityId: String
    let authorId: String
    var text: String?
    var imageURL: URL?
    let createdAt: Date
}

/// Feed row: post + resolved author profile (author may be missing if profile was deleted).
struct CommunityPostItem: Equatable, Sendable, Identifiable {
    let post: CommunityPost
    let author: User?

    var id: String { post.id }
}
