import Foundation

final class StubProfileImageStorage: ProfileImageStorage, @unchecked Sendable {
    func uploadProfileImage(data: Data, userId: String, postId: String) async throws -> URL {
        URL(string: "https://example.com/profilePosts/\(userId)/\(postId).jpg")
            ?? URL(fileURLWithPath: "/tmp/\(postId).jpg")
    }

    func deleteProfileImage(userId: String, postId: String) async throws {}
}
