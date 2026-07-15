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
    private let webSocketClient: WebSocketClientProtocol

    private var db: Firestore { Firestore.firestore() }

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(imageStorage: ChatImageStorage, webSocketClient: WebSocketClientProtocol) {
        self.imageStorage = imageStorage
        self.webSocketClient = webSocketClient
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

        try await ensureChatAccess(chatId: chatId, senderId: senderId)

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

        try await ensureChatAccess(chatId: chatId, senderId: senderId)

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
                "participantIds": FieldValue.arrayUnion([senderId])
            ],
            forDocument: chatRef,
            merge: true
        )

        // Step 1: Firestore write (source of truth).
        try await batch.commit()

        // Step 2: WebSocket broadcast for foreground instant delivery.
        // Failure is non-fatal — recipient can sync via Firestore or FCM later.
        broadcastMessage(
            chatId: chatId,
            text: hasText ? (trimmedText ?? "") : "Photo",
            clientMessageId: clientMessageId
        )
    }

    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { continuation in
            let observationTask = Task {
                for await event in webSocketClient.observeEvents() {
                    guard !Task.isCancelled else { break }

                    guard case let .messageNew(
                        eventChatId,
                        messageId,
                        senderId,
                        text,
                        createdAt,
                        clientMessageId
                    ) = event,
                    eventChatId == chatId else {
                        continue
                    }

                    let message = Message(
                        id: messageId,
                        chatId: chatId,
                        senderId: senderId,
                        text: text.isEmpty ? nil : text,
                        imageURL: nil,
                        createdAt: Self.parseCreatedAt(createdAt),
                        clientMessageId: clientMessageId ?? messageId,
                        status: .sent
                    )

                    continuation.yield(message)
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                observationTask.cancel()
            }
        }
    }

    func createDirectChat(with userId: String) async throws -> String {
        "stub-direct-\(userId)"
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        "stub-group-\(communityId)"
    }

    // MARK: - Private

    private func broadcastMessage(chatId: String, text: String, clientMessageId: String) {
        webSocketClient.send(
            event: .message(
                chatId: chatId,
                text: text,
                clientMessageId: clientMessageId
            )
        )
    }

    private static func parseCreatedAt(_ value: String) -> Date {
        iso8601WithFractionalSeconds.date(from: value)
            ?? iso8601.date(from: value)
            ?? Date()
    }

    /// Ensures the chat document exists and the current user is a participant.
    /// Uses merge + arrayUnion only — never reads the chat doc first, because
    /// Firestore read rules deny non-participants on existing chats.
    private func ensureChatAccess(chatId: String, senderId: String) async throws {
        let chatRef = db.collection(chatsCollection).document(chatId)
        try await chatRef.setData(
            [
                "type": ChatType.direct.rawValue,
                "title": "Chat",
                "participantIds": FieldValue.arrayUnion([senderId]),
                "lastMessageAt": Timestamp(date: Date())
            ],
            merge: true
        )
    }
}
