import Foundation
import Supabase

enum SupabaseProfileImageStorageError: LocalizedError {
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

/// Same `chat-images` bucket as chat — path prefix `profilePosts/{userId}/{postId}.jpg`.
final class SupabaseProfileImageStorage: ProfileImageStorage, @unchecked Sendable {
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

    func uploadProfileImage(data: Data, userId: String, postId: String) async throws -> URL {
        guard let storage else {
            throw SupabaseProfileImageStorageError.notConfigured
        }

        let path = storagePath(userId: userId, postId: postId)
        let options = FileOptions(contentType: "image/jpeg", upsert: true)

        do {
            try await storage
                .from(bucket)
                .upload(path, data: data, options: options)
        } catch {
            throw SupabaseProfileImageStorageError.uploadFailed
        }

        return try storage
            .from(bucket)
            .getPublicURL(path: path)
    }

    func deleteProfileImage(userId: String, postId: String) async throws {
        guard let storage else {
            throw SupabaseProfileImageStorageError.notConfigured
        }

        let path = storagePath(userId: userId, postId: postId)

        do {
            try await storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            throw SupabaseProfileImageStorageError.deleteFailed
        }
    }

    private func storagePath(userId: String, postId: String) -> String {
        "profilePosts/\(userId)/\(postId).jpg"
    }
}
