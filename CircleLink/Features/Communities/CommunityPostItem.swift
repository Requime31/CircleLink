import Foundation

/// Feed row view-data: post + resolved author profile.
/// Author may be `nil` if the profile was deleted.
/// Lives in presentation — not a Domain entity.
nonisolated struct CommunityPostItem: Equatable, Sendable, Identifiable {
    let post: CommunityPost
    let author: User?

    var id: String { post.id }
}
