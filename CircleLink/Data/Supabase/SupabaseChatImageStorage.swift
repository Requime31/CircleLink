import Foundation
import Supabase

enum SupabaseChatImageStorageError: LocalizedError {
    case notConfigured
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Copy SupabaseSecrets.plist.example to SupabaseSecrets.plist and add your keys."
        case .uploadFailed:
            return "Failed to upload image to cloud storage."
        }
    }
}

final class SupabaseChatImageStorage: ChatImageStorage, @unchecked Sendable {
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

    func uploadChatImage(data: Data, chatId: String, messageId: String) async throws -> URL {
        guard let storage else {
            throw SupabaseChatImageStorageError.notConfigured
        }

        let path = "chats/\(chatId)/\(messageId).jpg"
        let options = FileOptions(contentType: "image/jpeg", upsert: true)

        do {
            try await storage
                .from(bucket)
                .upload(path, data: data, options: options)
        } catch {
            throw SupabaseChatImageStorageError.uploadFailed
        }

        return try storage
            .from(bucket)
            .getPublicURL(path: path)
    }
}
