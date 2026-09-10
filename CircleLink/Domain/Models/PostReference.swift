import Foundation

struct PostReference: Hashable, Codable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable { case community, profile }
    let kind: Kind
    let ownerId: String
    let postId: String
    var id: String { path }
    var path: String {
        kind == .community ? "communities/\(ownerId)/posts/\(postId)" : "users/\(ownerId)/profilePosts/\(postId)"
    }
}

extension CommunityPost {
    var reference: PostReference { .init(kind: .community, ownerId: communityId, postId: id) }
}
extension ProfilePost {
    var reference: PostReference { .init(kind: .profile, ownerId: authorId, postId: id) }
}

struct PostLikeSnapshot: Equatable, Sendable {
    var count = 0
    var isLiked = false
    var exists = true
}

protocol PostLikeService: Sendable {
    func setLiked(_ liked: Bool, post: PostReference, userId: String) async throws -> PostLikeSnapshot
    func observeCount(post: PostReference) -> AsyncThrowingStream<Int?, Error>
    func observeLike(post: PostReference, userId: String) -> AsyncThrowingStream<Bool, Error>
    func canNavigate(userId: String, viewerId: String) async throws -> Bool
    func likerIds(post: PostReference, after: String?, limit: Int) async throws -> [String]
}
