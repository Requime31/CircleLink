import Foundation

/// Cloud storage for community post images (Supabase).
/// Firestore stores only the resulting public `imageURL`.
protocol CommunityImageStorage: Sendable {
    func uploadCommunityImage(data: Data, communityId: String, postId: String) async throws -> URL
    /// Best-effort cleanup when a post doc write fails or the author deletes the post.
    func deleteCommunityImage(communityId: String, postId: String) async throws
}
