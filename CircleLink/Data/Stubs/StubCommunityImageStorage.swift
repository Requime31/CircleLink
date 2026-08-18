import Foundation

final class StubCommunityImageStorage: CommunityImageStorage, @unchecked Sendable {
    func uploadCover(data: Data, communityId: String) async throws -> URL {
        URL(string: "https://example.com/communities/\(communityId)/cover.jpg")!
    }
    func uploadPostImage(data: Data, communityId: String, postId: String) async throws -> URL {
        URL(string: "https://example.com/communityPosts/\(communityId)/\(postId).jpg")!
    }
    func deleteCover(communityId: String) async throws {}
    func deletePostImage(communityId: String, postId: String) async throws {}
}
