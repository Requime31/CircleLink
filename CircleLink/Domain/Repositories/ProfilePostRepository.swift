import Foundation

/// Owner profile posts — Firestore docs + optional Supabase image upload.
protocol ProfilePostRepository: Sendable {
    /// Newest first. Pass `before` (oldest `createdAt` already loaded) for the next page.
    func fetchPosts(userId: String, limit: Int, before: Date?) async throws -> [ProfilePost]

    /// Cheap count for profile stats (server aggregation when available).
    func fetchPostCount(userId: String) async throws -> Int

    /// Creates a post for the signed-in user. Generates storage path from `postId` when `image` is set.
    func createPost(postId: String, text: String?, image: Data?) async throws -> ProfilePost

    /// Updates an existing post. Author only.
    /// - `image`: new bytes to upload (replaces existing storage object).
    /// - `removeImage`: drop `imageURL` and best-effort delete storage (ignored when `image` is set).
    /// - Otherwise keep the existing `imageURL`.
    func updatePost(
        _ post: ProfilePost,
        text: String?,
        image: Data?,
        removeImage: Bool
    ) async throws -> ProfilePost

    /// Deletes the Firestore doc and best-effort removes the image from storage. Author only.
    func deletePost(_ post: ProfilePost) async throws
}
