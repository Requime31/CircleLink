import Foundation

/// A post on a user's profile (`users/{userId}/profilePosts/{postId}`).
/// Separate from community feed posts. At least one of `text` / `imageURL` must be present.
struct ProfilePost: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let authorId: String
    var text: String?
    var imageURL: URL?
    let createdAt: Date
}
