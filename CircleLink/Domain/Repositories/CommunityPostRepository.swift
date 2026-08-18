import Foundation

protocol CommunityPostRepository: Sendable {
    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost]
    func createPost(communityId: String, postId: String, text: String?, image: Data?) async throws -> CommunityPost
    func updatePost(_ post: CommunityPost, text: String?, image: Data?, removeImage: Bool) async throws -> CommunityPost
    func deletePost(_ post: CommunityPost) async throws
}
