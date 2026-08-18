import Foundation

protocol CommunityImageStorage: Sendable {
    func uploadCover(data: Data, communityId: String) async throws -> URL
    func uploadPostImage(data: Data, communityId: String, postId: String) async throws -> URL
    func deleteCover(communityId: String) async throws
    func deletePostImage(communityId: String, postId: String) async throws
}
