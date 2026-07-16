import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreChatError: LocalizedError {
    case notAuthenticated
    case missingTextAndImage
    case uploadFailed
    case invalidPeer
    case chatNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use chat."
        case .missingTextAndImage:
            return "Message must include text or an image."
        case .uploadFailed:
            return "Failed to upload image."
        case .invalidPeer:
            return "Cannot create a chat with yourself."
        case .chatNotFound:
            return "Chat could not be found."
        }
    }
}

final class FirestoreChatRepository: ChatRepository, @unchecked Sendable {
    /// Recent window for the live listener — large enough to overlap `fetchMessages` pages
    /// and catch mid-flight sends without dumping the full history on first snapshot.
    private static let liveMessagesWindowSize = 50

    private let chatsCollection = "chats"
    private let messagesCollection = "messages"
    private let usersCollection = "users"
    private let chatRefsCollection = "chatRefs"
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

        let refsSnapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection(chatRefsCollection)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        var summaries: [ChatSummary] = []
        summaries.reserveCapacity(refsSnapshot.documents.count)

        for refDoc in refsSnapshot.documents {
            let chatId = refDoc.documentID
            let chatDoc = try await db.collection(chatsCollection).document(chatId).getDocument()
            guard chatDoc.exists else { continue }

            let data = chatDoc.data() ?? [:]
            let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue
            let type = ChatType(rawValue: typeRaw) ?? .direct
            let participants = FirestoreChatMapper.participantIds(from: data)

            var titleOverride: String?
            var avatarURL: URL?
            var avatarBase64: String?

            if type == .direct,
               let peerId = participants.first(where: { $0 != userId }),
               let peer = try await fetchUser(userId: peerId) {
                titleOverride = peer.displayName.isEmpty ? "Chat" : peer.displayName
                avatarURL = peer.avatarURL
                avatarBase64 = peer.avatarBase64
            }

            var summary = try FirestoreChatMapper.chatSummary(
                from: chatDoc,
                titleOverride: titleOverride,
                avatarURL: avatarURL,
                avatarBase64: avatarBase64
            )

            // Prefer ref timestamps when chat doc is missing lastMessageAt.
            let refData = refDoc.data()
            if summary.lastMessageAt == nil {
                summary.lastMessageAt = (refData["lastMessageAt"] as? Timestamp)?.dateValue()
            }
            if summary.lastMessageText == nil {
                summary.lastMessageText = refData["lastMessageText"] as? String
            }

            summaries.append(summary)
        }

        return summaries.sorted {
            ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
        }
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

        // Ensure participant list is known before updating peer chatRefs (security rules).
        let participantIds = try await resolveParticipantIds(chatId: chatId, fallback: [senderId])

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

        let refPayload = FirestoreChatMapper.chatRefData(
            lastMessageText: previewText,
            lastMessageAt: createdAt
        )
        for participantId in participantIds {
            let userChatRef = db.collection(usersCollection)
                .document(participantId)
                .collection(chatRefsCollection)
                .document(chatId)
            batch.setData(refPayload, forDocument: userChatRef, merge: true)
        }

        // Firestore write is the single source of truth for messages.
        // Instant delivery comes from addSnapshotListener in observeLiveMessages.
        try await batch.commit()
    }

    /// Live messages while the chat screen is open.
    /// Uses `limit(toLast:)` so the first snapshot is a recent window (overlaps history fetch),
    /// not the entire chat history — VM dedup + older-than-page filter handle the overlap.
    /// Listener is removed when the AsyncStream terminates (VM cancels observe Task).
    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { continuation in
            let query = db.collection(chatsCollection)
                .document(chatId)
                .collection(messagesCollection)
                .order(by: "createdAt", descending: false)
                .limit(toLast: Self.liveMessagesWindowSize)

            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    print("[FirestoreChatRepository] messages listener error: \(error.localizedDescription)")
                    return
                }

                guard let snapshot else { return }

                for change in snapshot.documentChanges {
                    guard change.type == .added || change.type == .modified else {
                        continue
                    }

                    do {
                        let message = try FirestoreChatMapper.message(
                            from: change.document,
                            chatId: chatId
                        )
                        continuation.yield(message)
                    } catch {
                        print("[FirestoreChatRepository] message map failed: \(error.localizedDescription)")
                    }
                }
            }

            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

    func createDirectChat(with userId: String) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        guard currentUserId != userId else {
            throw FirestoreChatError.invalidPeer
        }

        let chatId = FirestoreChatMapper.directChatId(userIdA: currentUserId, userIdB: userId)
        let chatRef = db.collection(chatsCollection).document(chatId)
        let existing = try await chatRef.getDocument()

        if existing.exists {
            try await ensureChatRefsExist(
                chatId: chatId,
                participantIds: [currentUserId, userId],
                lastMessageText: existing.data()?["lastMessageText"] as? String,
                lastMessageAt: (existing.data()?["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date()
            )
            return chatId
        }

        let peer = try await fetchUser(userId: userId)
        let peerName = peer?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = peerName.isEmpty ? "Chat" : peerName
        let now = Date()

        // Step 1: write chat first so security rules can see participantIds
        // when we write the peer's chatRef in step 2.
        try await chatRef.setData(
            [
                "type": ChatType.direct.rawValue,
                "title": title,
                "participantIds": [currentUserId, userId],
                "lastMessageText": NSNull(),
                "lastMessageAt": Timestamp(date: now),
                "unreadCount": 0
            ],
            merge: true
        )

        // Step 2: mirror refs for both participants (needed for chat list).
        let batch = db.batch()
        let refPayload = FirestoreChatMapper.chatRefData(lastMessageText: nil, lastMessageAt: now)
        for participantId in [currentUserId, userId] {
            let userChatRef = db.collection(usersCollection)
                .document(participantId)
                .collection(chatRefsCollection)
                .document(chatId)
            batch.setData(refPayload, forDocument: userChatRef, merge: true)
        }

        try await batch.commit()
        return chatId
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        "stub-group-\(communityId)"
    }

    // MARK: - Private

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

        let ref = db.collection(usersCollection)
            .document(senderId)
            .collection(chatRefsCollection)
            .document(chatId)
        try await ref.setData(
            FirestoreChatMapper.chatRefData(lastMessageText: nil, lastMessageAt: Date()),
            merge: true
        )
    }

    private func fetchUser(userId: String) async throws -> User? {
        let document = try await db.collection(usersCollection).document(userId).getDocument()
        guard document.exists else { return nil }
        return try FirestoreUserMapper.user(from: document)
    }

    private func resolveParticipantIds(chatId: String, fallback: [String]) async throws -> [String] {
        let chatDoc = try await db.collection(chatsCollection).document(chatId).getDocument()
        let ids = FirestoreChatMapper.participantIds(from: chatDoc.data() ?? [:])
        return ids.isEmpty ? fallback : ids
    }

    private func ensureChatRefsExist(
        chatId: String,
        participantIds: [String],
        lastMessageText: String?,
        lastMessageAt: Date
    ) async throws {
        let batch = db.batch()
        let payload = FirestoreChatMapper.chatRefData(
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt
        )
        for participantId in participantIds {
            let ref = db.collection(usersCollection)
                .document(participantId)
                .collection(chatRefsCollection)
                .document(chatId)
            batch.setData(payload, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }
}
