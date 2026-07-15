import Foundation

/// Cloud storage for chat image attachments.
/// Firestore stores only the resulting `imageURL` — not the binary.
protocol ChatImageStorage: Sendable {
    func uploadChatImage(data: Data, chatId: String, messageId: String) async throws -> URL
}
