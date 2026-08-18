import Foundation
import Supabase

final class SupabaseCommunityImageStorage: CommunityImageStorage, @unchecked Sendable {
    private let storage: SupabaseStorageClient?
    private let bucket: String

    init(storage: SupabaseStorageClient? = nil, bucket: String = SupabaseConfiguration.chatImagesBucket) {
        self.storage = storage ?? SupabaseConfiguration.makeStorageClient()
        self.bucket = bucket
    }

    func uploadCover(data: Data, communityId: String) async throws -> URL {
        try await upload(data: data, path: "communities/\(communityId)/cover.jpg")
    }

    func uploadPostImage(data: Data, communityId: String, postId: String) async throws -> URL {
        try await upload(data: data, path: "communityPosts/\(communityId)/\(postId).jpg")
    }

    func deleteCover(communityId: String) async throws {
        try await delete(path: "communities/\(communityId)/cover.jpg")
    }

    func deletePostImage(communityId: String, postId: String) async throws {
        try await delete(path: "communityPosts/\(communityId)/\(postId).jpg")
    }

    private func upload(data: Data, path: String) async throws -> URL {
        guard let storage else { throw SupabaseProfileImageStorageError.notConfigured }
        do {
            try await storage.from(bucket).upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            return try storage.from(bucket).getPublicURL(path: path)
        } catch {
            throw SupabaseProfileImageStorageError.uploadFailed
        }
    }

    private func delete(path: String) async throws {
        guard let storage else { throw SupabaseProfileImageStorageError.notConfigured }
        do {
            try await storage.from(bucket).remove(paths: [path])
        } catch {
            throw SupabaseProfileImageStorageError.deleteFailed
        }
    }
}
