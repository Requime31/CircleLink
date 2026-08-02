import Foundation

/// Community feed posts — Firestore docs + optional Supabase image upload.
protocol CommunityPostRepository: Sendable {
    /// Newest first. Pass `before` (oldest `createdAt` already loaded) for the next page.
    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost]

    /// Creates a post. Generates storage path from `postId` when `image` is set.
    /// - Requires trimmed text and/or image; empty both → error.
    func createPost(
        communityId: String,
        postId: String,
        text: String?,
        image: Data?
    ) async throws -> CommunityPost

    /// Deletes the Firestore doc and best-effort removes the image from storage.
    func deletePost(_ post: CommunityPost) async throws
}
