import Foundation
import Supabase

enum SupabaseCommunityImageStorageError: LocalizedError {
    case notConfigured
    case uploadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Copy SupabaseSecrets.plist.example to SupabaseSecrets.plist and add your keys."
        case .uploadFailed:
            return "Failed to upload image to cloud storage."
        case .deleteFailed:
            return "Failed to delete image from cloud storage."
        }
    }
}

/// Same `chat-images` bucket as chat — path prefix `communities/{communityId}/{postId}.jpg`.
final class SupabaseCommunityImageStorage: CommunityImageStorage, @unchecked Sendable {
    private let storage: SupabaseStorageClient?
    private let bucket: String

    init(
        storage: SupabaseStorageClient? = nil,
        bucket: String = SupabaseConfiguration.chatImagesBucket
    ) {
        if let storage {
            self.storage = storage
            self.bucket = bucket
            return
        }

        self.storage = SupabaseConfiguration.makeStorageClient()
        self.bucket = bucket
    }

    func uploadCommunityImage(data: Data, communityId: String, postId: String) async throws -> URL {
        guard let storage else {
            throw SupabaseCommunityImageStorageError.notConfigured
        }

        let path = storagePath(communityId: communityId, postId: postId)
        let options = FileOptions(contentType: "image/jpeg", upsert: true)

        do {
            try await storage
                .from(bucket)
                .upload(path, data: data, options: options)
        } catch {
            throw SupabaseCommunityImageStorageError.uploadFailed
        }

        return try storage
            .from(bucket)
            .getPublicURL(path: path)
    }

    func deleteCommunityImage(communityId: String, postId: String) async throws {
        guard let storage else {
            throw SupabaseCommunityImageStorageError.notConfigured
        }

        let path = storagePath(communityId: communityId, postId: postId)

        do {
            try await storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            throw SupabaseCommunityImageStorageError.deleteFailed
        }
    }

    private func storagePath(communityId: String, postId: String) -> String {
        "communities/\(communityId)/\(postId).jpg"
    }
}
