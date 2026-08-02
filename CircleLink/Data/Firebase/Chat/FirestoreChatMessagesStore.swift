import FirebaseFirestore
import Foundation

/// Message history fetch + send (including image upload).
final class FirestoreChatMessagesStore: @unchecked Sendable {
    private let support: FirestoreChatSupport
    private let imageStorage: ChatImageStorage

    init(support: FirestoreChatSupport, imageStorage: ChatImageStorage) {
        self.support = support
        self.imageStorage = imageStorage
    }

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        let senderId = try support.requireCurrentUserId()

        try await support.ensureChatAccess(chatId: chatId, senderId: senderId)

        var query: Query = support.db.collection(support.chatsCollection)
            .document(chatId)
            .collection(support.messagesCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let before {
            query = query.start(after: [Timestamp(date: before)])
        }

        let snapshot = try await query.getDocuments()
        let messages = try snapshot.documents.map { try FirestoreChatMapper.message(from: $0, chatId: chatId) }
        return messages.sorted { $0.createdAt < $1.createdAt }
    }

    func sendMessage(
        chatId: String,
        text: String?,
        image: Data?,
        clientMessageId: String
    ) async throws {
        let senderId = try support.requireCurrentUserId()

        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmedText?.isEmpty ?? true)
        let hasImage = image != nil

        guard hasText || hasImage else {
            throw FirestoreChatError.missingTextAndImage
        }

        let messageId = clientMessageId
        let createdAt = Date()

        try await support.ensureChatAccess(chatId: chatId, senderId: senderId)

        var imageURL: URL?
        if let image {
            // Single-compress: UI passes original bytes; size policy applied here once.
            let compressed = try await ImageCompressor.compressForChatOffMain(image)
            imageURL = try await imageStorage.uploadChatImage(
                data: compressed,
                chatId: chatId,
                messageId: messageId
            )
        }

        let messageRef = support.db.collection(support.chatsCollection)
            .document(chatId)
            .collection(support.messagesCollection)
            .document(messageId)

        let data = FirestoreChatMapper.messageData(
            senderId: senderId,
            text: hasText ? trimmedText : nil,
            imageURL: imageURL,
            clientMessageId: clientMessageId,
            createdAt: createdAt
        )

        let previewText = hasText ? trimmedText : "Photo"

        // Ensure participant list is known before updating peer chatRefs (security rules).
        let participantIds = try await support.resolveParticipantIds(chatId: chatId, fallback: [senderId])

        // Message + chat metadata in one batch (small). ChatRefs are chunked separately
        // so large group chats stay under Firestore's 500-writes-per-batch limit.
        let batch = support.db.batch()
        batch.setData(data, forDocument: messageRef)

        // Do not overwrite `type` / `title` — group chats must stay `type: group`.
        let chatRef = support.db.collection(support.chatsCollection).document(chatId)
        batch.setData(
            [
                "lastMessageText": previewText ?? NSNull(),
                "lastMessageAt": Timestamp(date: createdAt),
                "participantIds": FieldValue.arrayUnion([senderId])
            ],
            forDocument: chatRef,
            merge: true
        )

        // Firestore write is the single source of truth for messages.
        // Instant delivery comes from addSnapshotListener in observeLiveMessages.
        try await batch.commit()

        try await support.ensureChatRefsExist(
            chatId: chatId,
            participantIds: participantIds,
            lastMessageText: previewText,
            lastMessageAt: createdAt
        )
    }
}
