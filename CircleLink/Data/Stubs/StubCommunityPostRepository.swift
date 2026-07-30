import Foundation

final class StubCommunityPostRepository: CommunityPostRepository, @unchecked Sendable {
    private var postsByCommunity: [String: [CommunityPost]] = [:]

    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost] {
        let sorted = (postsByCommunity[communityId] ?? [])
            .sorted { $0.createdAt > $1.createdAt }

        let filtered: [CommunityPost]
        if let before {
            filtered = sorted.filter { $0.createdAt < before }
        } else {
            filtered = sorted
        }

        return Array(filtered.prefix(limit))
    }

    func createPost(
        communityId: String,
        postId: String,
        text: String?,
        image: Data?
    ) async throws -> CommunityPost {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        guard hasText || image != nil else {
            throw FirestoreCommunityPostError.emptyContent
        }

        let post = CommunityPost(
            id: postId,
            communityId: communityId,
            authorId: "stub-user",
            text: hasText ? trimmed : nil,
            imageURL: image == nil ? nil : URL(string: "https://example.com/\(postId).jpg"),
            createdAt: Date()
        )
        postsByCommunity[communityId, default: []].insert(post, at: 0)
        return post
    }

    func deletePost(_ post: CommunityPost) async throws {
        postsByCommunity[post.communityId]?.removeAll { $0.id == post.id }
    }
}
