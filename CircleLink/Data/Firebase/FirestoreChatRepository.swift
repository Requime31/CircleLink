import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreChatError: LocalizedError {
    case notAuthenticated
    case missingTextAndImage
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use chat."
        case .missingTextAndImage:
            return "Message must include text or an image."
        case .uploadFailed:
            return "Failed to upload image."
        }
    }
}

final class FirestoreChatRepository: ChatRepository, @unchecked Sendable {
    private let chatsCollection = "chats"
    private let messagesCollection = "messages"
    private let imageStorage: ChatImageStorage

    private var db: Firestore { Firestore.firestore() }

    init(imageStorage: ChatImageStorage) {
        self.imageStorage = imageStorage
    }

    // MARK: - ChatRepository

    func fetchChats() async throws -> [ChatSummary] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        let snapshot = try await db.collection(chatsCollection)
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return try snapshot.documents.map { try FirestoreChatMapper.chatSummary(from: $0) }
    }

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        guard let senderId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        try await ensureChatExists(chatId: chatId, senderId: senderId)

        var query: Query = db.collection(chatsCollection)
            .document(chatId)
            .collection(messagesCollection)
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
        guard let senderId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmedText?.isEmpty ?? true)
        let hasImage = image != nil

        guard hasText || hasImage else {
            throw FirestoreChatError.missingTextAndImage
        }

        let messageId = clientMessageId
        let createdAt = Date()

        try await ensureChatExists(chatId: chatId, senderId: senderId)

        var imageURL: URL?
        if let image {
            let compressed = try ImageCompressor.compressForChat(image)
            imageURL = try await imageStorage.uploadChatImage(
                data: compressed,
                chatId: chatId,
                messageId: messageId
            )
        }

        let messageRef = db.collection(chatsCollection)
            .document(chatId)
            .collection(messagesCollection)
            .document(messageId)

        let data = FirestoreChatMapper.messageData(
            senderId: senderId,
            text: hasText ? trimmedText : nil,
            imageURL: imageURL,
            clientMessageId: clientMessageId,
            createdAt: createdAt
        )

        let previewText = hasText ? trimmedText : "Photo"
        let batch = db.batch()
        batch.setData(data, forDocument: messageRef)

        let chatRef = db.collection(chatsCollection).document(chatId)
        batch.setData(
            [
                "lastMessageText": previewText ?? NSNull(),
                "lastMessageAt": Timestamp(date: createdAt),
                "type": ChatType.direct.rawValue,
                "title": "Chat",
                "participantIds": [senderId]
            ],
            forDocument: chatRef,
            merge: true
        )

        try await batch.commit()
    }

    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { _ in }
    }

    func createDirectChat(with userId: String) async throws -> String {
        "stub-direct-\(userId)"
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        "stub-group-\(communityId)"
    }

    // MARK: - Private

    private func ensureChatExists(chatId: String, senderId: String) async throws {
        let chatRef = db.collection(chatsCollection).document(chatId)
        let snapshot = try await chatRef.getDocument()

        guard !snapshot.exists else { return }

        try await chatRef.setData([
            "type": ChatType.direct.rawValue,
            "title": "Chat",
            "participantIds": [senderId],
            "lastMessageAt": Timestamp(date: Date())
        ])
    }
}
