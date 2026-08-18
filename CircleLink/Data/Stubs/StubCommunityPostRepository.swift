import Foundation

final class StubCommunityPostRepository: CommunityPostRepository, @unchecked Sendable {
    private var posts: [CommunityPost] = []
    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost] {
        Array(posts.filter { $0.communityId == communityId }.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
    func createPost(communityId: String, postId: String, text: String?, image: Data?) async throws -> CommunityPost {
        let post = CommunityPost(id: postId, communityId: communityId, authorId: "stub-user", text: text, imageURL: image == nil ? nil : URL(string: "https://example.com/\(postId).jpg"), createdAt: Date())
        posts.insert(post, at: 0)
        return post
    }
    func updatePost(_ post: CommunityPost, text: String?, image: Data?, removeImage: Bool) async throws -> CommunityPost { post }
    func deletePost(_ post: CommunityPost) async throws { posts.removeAll { $0.id == post.id } }
}
