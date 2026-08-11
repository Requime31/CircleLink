import Foundation

/// Cloud storage for profile post images (Supabase).
/// Firestore stores only the resulting public `imageURL`.
protocol ProfileImageStorage: Sendable {
    func uploadProfileImage(data: Data, userId: String, postId: String) async throws -> URL
    /// Best-effort cleanup when a post doc write fails or the author deletes the post.
    func deleteProfileImage(userId: String, postId: String) async throws
}
