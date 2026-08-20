import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreChatError: LocalizedError {
    case notAuthenticated
    case missingTextAndImage
    case uploadFailed
    case invalidPeer
    case chatNotFound
    case notCommunityMember
    case emptyParticipants
    case notDirectChat

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
        case .notCommunityMember:
            return "Only community members can open this group chat."
        case .emptyParticipants:
            return "Group chat needs at least one member."
        case .notDirectChat:
            return "This action is only available for direct chats."
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
    private let communitiesCollection = "communities"
    private let chatRefsCollection = "chatRefs"
    private let imageStorage: ChatImageStorage

    private var db: Firestore { Firestore.firestore() }

    init(imageStorage: ChatImageStorage) {
        self.imageStorage = imageStorage
    }

    // MARK: - ChatRepository

    func fetchChats() async throws -> [ChatSummary] {
        try await fetchOrganizedChats().visible
    }

    func fetchHiddenChats() async throws -> [ChatSummary] {
        try await fetchOrganizedChats().hidden
    }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        // Soft limit covers active + hidden; hidden are filtered client-side.
        let refsSnapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection(chatRefsCollection)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 100)
            .getDocuments()

        var visible: [ChatSummary] = []
        var hidden: [ChatSummary] = []
        visible.reserveCapacity(refsSnapshot.documents.count)
        hidden.reserveCapacity(8)

        for refDoc in refsSnapshot.documents {
            let refData = refDoc.data()
            guard let summary = try await makeSummary(
                chatId: refDoc.documentID,
                refData: refData,
                currentUserId: userId
            ) else { continue }

            if FirestoreChatMapper.isHiddenChatRef(refData) {
                hidden.append(summary)
            } else {
                visible.append(summary)
            }
        }

        let byRecency: (ChatSummary, ChatSummary) -> Bool = {
            ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
        }
        return OrganizedChats(
            visible: visible.sorted(by: byRecency),
            hidden: hidden.sorted(by: byRecency)
        )
    }

    func setChatMuted(chatId: String, muted: Bool) async throws {
        try await updateOwnChatRef(chatId: chatId, data: ["muted": muted])
    }

    func hideChat(chatId: String) async throws {
        try await updateOwnChatRef(
            chatId: chatId,
            data: [
                "hidden": true,
                "hiddenAt": Timestamp(date: Date())
            ]
        )
    }

    func unhideChat(chatId: String) async throws {
        try await updateOwnChatRef(
            chatId: chatId,
            data: [
                "hidden": false,
                "hiddenAt": FieldValue.delete()
            ]
        )
    }

    func fetchChatInfo(chatId: String) async throws -> ChatInfo {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        let chatDoc = try await db.collection(chatsCollection).document(chatId).getDocument()
        guard chatDoc.exists else {
            throw FirestoreChatError.chatNotFound
        }

        let data = chatDoc.data() ?? [:]
        let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue
        let type = ChatType(rawValue: typeRaw) ?? .direct
        let communityId = (data["communityId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCommunityId = (communityId?.isEmpty == false) ? communityId : nil
        let title = (data["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String
        if let title, !title.isEmpty {
            resolvedTitle = title
        } else {
            resolvedTitle = "Chat"
        }
        let participantIds = FirestoreChatMapper.participantIds(from: data)

        var participants: [User] = []
        participants.reserveCapacity(participantIds.count)
        for participantId in participantIds {
            if let user = try await fetchUser(userId: participantId) {
                participants.append(user)
            }
        }

        let refData = try await ownChatRefData(userId: userId, chatId: chatId)

        return ChatInfo(
            id: chatId,
            type: type,
            title: resolvedTitle,
            communityId: resolvedCommunityId,
            participants: participants,
            isMuted: FirestoreChatMapper.isMutedChatRef(refData),
            clearedAt: FirestoreChatMapper.clearedAt(from: refData)
        )
    }

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        guard let senderId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        try await ensureChatAccess(chatId: chatId, senderId: senderId)
        let clearedAt = try await ownClearedAt(userId: senderId, chatId: chatId)

        // Fetch a bit more when filtering by watermark so pages stay useful.
        let fetchLimit = min(limit * 3, 90)
        var collected: [Message] = []
        var cursor = before
        var pagesWithoutProgress = 0

        while collected.count < limit, pagesWithoutProgress < 3 {
            var query: Query = db.collection(chatsCollection)
                .document(chatId)
                .collection(messagesCollection)
                .order(by: "createdAt", descending: true)
                .limit(to: fetchLimit)

            if let cursor {
                query = query.start(after: [Timestamp(date: cursor)])
            }

            let snapshot = try await query.getDocuments()
            if snapshot.documents.isEmpty { break }

            let page = try snapshot.documents.map { try FirestoreChatMapper.message(from: $0, chatId: chatId) }
            let visible = page.filter { Self.isVisibleAfterClear($0, clearedAt: clearedAt) }
            let beforeCount = collected.count
            for message in visible where collected.count < limit {
                collected.append(message)
            }

            cursor = page.last?.createdAt
            if collected.count == beforeCount {
                pagesWithoutProgress += 1
            } else {
                pagesWithoutProgress = 0
            }

            // Older than watermark — no need to keep paging into cleared history.
            if let clearedAt, let oldest = page.last?.createdAt, oldest <= clearedAt {
                break
            }
            if page.count < fetchLimit { break }
        }

        return collected.sorted { $0.createdAt < $1.createdAt }
    }

    func fetchChatMedia(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        guard let senderId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        try await ensureChatAccess(chatId: chatId, senderId: senderId)
        let clearedAt = try await ownClearedAt(userId: senderId, chatId: chatId)

        var collected: [Message] = []
        var cursor = before
        var pagesWithoutProgress = 0
        let pageSize = 40

        while collected.count < limit, pagesWithoutProgress < 5 {
            var query: Query = db.collection(chatsCollection)
                .document(chatId)
                .collection(messagesCollection)
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)

            if let cursor {
                query = query.start(after: [Timestamp(date: cursor)])
            }

            let snapshot = try await query.getDocuments()
            if snapshot.documents.isEmpty { break }

            let page = try snapshot.documents.map { try FirestoreChatMapper.message(from: $0, chatId: chatId) }
            let beforeCount = collected.count
            for message in page {
                guard Self.isVisibleAfterClear(message, clearedAt: clearedAt) else { continue }
                guard message.imageURL != nil else { continue }
                collected.append(message)
                if collected.count >= limit { break }
            }

            cursor = page.last?.createdAt
            if collected.count == beforeCount {
                pagesWithoutProgress += 1
            } else {
                pagesWithoutProgress = 0
            }

            if let clearedAt, let oldest = page.last?.createdAt, oldest <= clearedAt {
                break
            }
            if page.count < pageSize { break }
        }

        return collected
    }

    func clearChatHistory(chatId: String) async throws {
        try await updateOwnChatRef(
            chatId: chatId,
            data: ["clearedAt": Timestamp(date: Date())]
        )
    }

    func deleteDirectChat(chatId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        let chatDoc = try await db.collection(chatsCollection).document(chatId).getDocument()
        guard chatDoc.exists else {
            throw FirestoreChatError.chatNotFound
        }
        let typeRaw = chatDoc.data()?["type"] as? String ?? ChatType.direct.rawValue
        guard ChatType(rawValue: typeRaw) == .direct else {
            throw FirestoreChatError.notDirectChat
        }

        try await db.collection(usersCollection)
            .document(userId)
            .collection(chatRefsCollection)
            .document(chatId)
            .delete()
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

        // Message + chat metadata in one batch (small). ChatRefs are chunked separately
        // so large group chats stay under Firestore's 500-writes-per-batch limit.
        let batch = db.batch()
        batch.setData(data, forDocument: messageRef)

        // Do not overwrite `type` / `title` — group chats must stay `type: group`.
        let chatRef = db.collection(chatsCollection).document(chatId)
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

        try await ensureChatRefsExist(
            chatId: chatId,
            participantIds: participantIds,
            lastMessageText: previewText,
            lastMessageAt: createdAt
        )
    }

    /// Live messages while the chat screen is open.
    /// Uses `limit(toLast:)` so the first snapshot is a recent window (overlaps history fetch),
    /// not the entire chat history — VM dedup + older-than-page filter handle the overlap.
    /// Listener is removed when the AsyncStream terminates (VM cancels observe Task).
    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { continuation in
            let userId = Auth.auth().currentUser?.uid
            let db = self.db
            let chatsCollection = self.chatsCollection
            let messagesCollection = self.messagesCollection
            let usersCollection = self.usersCollection
            let chatRefsCollection = self.chatRefsCollection
            let windowSize = Self.liveMessagesWindowSize

            /// `onTermination` can race with async listener setup. The lock guarantees that
            /// a registration installed after termination is removed immediately.
            final class ListenerBox: @unchecked Sendable {
                private let lock = NSLock()
                private var registration: ListenerRegistration?
                private var isTerminated = false

                func install(_ registration: ListenerRegistration) {
                    lock.lock()
                    if isTerminated {
                        lock.unlock()
                        registration.remove()
                        return
                    }
                    self.registration = registration
                    lock.unlock()
                }

                func terminate() {
                    lock.lock()
                    isTerminated = true
                    let registration = self.registration
                    self.registration = nil
                    lock.unlock()
                    registration?.remove()
                }
            }
            let box = ListenerBox()

            let setupTask = Task {
                var clearedAt: Date?
                if let userId {
                    let snapshot = try? await db.collection(usersCollection)
                        .document(userId)
                        .collection(chatRefsCollection)
                        .document(chatId)
                        .getDocument()
                    clearedAt = FirestoreChatMapper.clearedAt(from: snapshot?.data() ?? [:])
                }

                guard !Task.isCancelled else { return }

                let query = db.collection(chatsCollection)
                    .document(chatId)
                    .collection(messagesCollection)
                    .order(by: "createdAt", descending: false)
                    .limit(toLast: windowSize)

                let registration = query.addSnapshotListener { snapshot, error in
                    if let error {
                        #if DEBUG
                        print("[FirestoreChatRepository] messages listener error: \(error.localizedDescription)")
                        #endif
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
                            guard Self.isVisibleAfterClear(message, clearedAt: clearedAt) else {
                                continue
                            }
                            continuation.yield(message)
                        } catch {
                            #if DEBUG
                            print("[FirestoreChatRepository] message map failed: \(error.localizedDescription)")
                            #endif
                        }
                    }
                }
                box.install(registration)
            }

            continuation.onTermination = { _ in
                setupTask.cancel()
                box.terminate()
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
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        let uniqueParticipants = Array(Set(participantIds)).sorted()
        guard !uniqueParticipants.isEmpty else {
            throw FirestoreChatError.emptyParticipants
        }

        guard uniqueParticipants.contains(currentUserId) else {
            throw FirestoreChatError.notCommunityMember
        }

        // Server-side membership check — don't trust client-only participant list.
        let memberDoc = try await db.collection(communitiesCollection)
            .document(communityId)
            .collection("members")
            .document(currentUserId)
            .getDocument()
        guard memberDoc.exists else {
            throw FirestoreChatError.notCommunityMember
        }

        let chatId = FirestoreChatMapper.groupChatId(communityId: communityId)
        let chatRef = db.collection(chatsCollection).document(chatId)
        let title = try await fetchCommunityName(communityId: communityId)
        let now = Date()

        // Write-first (merge + arrayUnion). Do not getDocument before join —
        // older rules denied reads for community members not yet in participantIds.
        try await chatRef.setData(
            [
                "type": ChatType.group.rawValue,
                "communityId": communityId,
                "title": title,
                "participantIds": FieldValue.arrayUnion(uniqueParticipants)
            ],
            merge: true
        )

        // Now a participant — safe to read for lastMessage seeding / chatRefs.
        let existing = try await chatRef.getDocument()
        let existingData = existing.data() ?? [:]
        let lastMessageText = existingData["lastMessageText"] as? String
        let lastMessageAt = (existingData["lastMessageAt"] as? Timestamp)?.dateValue()

        if lastMessageAt == nil {
            try await chatRef.setData(
                [
                    "lastMessageText": NSNull(),
                    "lastMessageAt": Timestamp(date: now)
                ],
                merge: true
            )
        }

        try await ensureChatRefsExist(
            chatId: chatId,
            participantIds: [currentUserId],
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt ?? now
        )
        return chatId
    }

    func leaveChat(chatId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        let chatRef = db.collection(chatsCollection).document(chatId)

        // Remove from participantIds only when present. Non-participants (or missing
        // chat) still drop their chatRef so Leave Community can finish cleanly.
        do {
            let existing = try await chatRef.getDocument()
            if existing.exists {
                let participants = FirestoreChatMapper.participantIds(from: existing.data() ?? [:])
                if participants.contains(currentUserId) {
                    try await chatRef.setData(
                        ["participantIds": FieldValue.arrayRemove([currentUserId])],
                        merge: true
                    )
                }
            }
        } catch {
            // Unreadable chat — still clear local ref below.
        }

        try await db.collection(usersCollection)
            .document(currentUserId)
            .collection(chatRefsCollection)
            .document(chatId)
            .delete()
    }

    func leaveGroupChat(communityId: String) async throws {
        let chatId = FirestoreChatMapper.groupChatId(communityId: communityId)
        try await leaveChat(chatId: chatId)
    }

    // MARK: - Private

    private func makeSummary(
        chatId: String,
        refData: [String: Any],
        currentUserId: String
    ) async throws -> ChatSummary? {
        let chatDoc = try await db.collection(chatsCollection).document(chatId).getDocument()
        guard chatDoc.exists else { return nil }

        let data = chatDoc.data() ?? [:]
        let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue
        let type = ChatType(rawValue: typeRaw) ?? .direct
        let participants = FirestoreChatMapper.participantIds(from: data)

        var titleOverride: String?
        var avatarURL: URL?
        var avatarBase64: String?
        var peerUserId: String?

        if type == .direct,
           let peerId = participants.first(where: { $0 != currentUserId }),
           let peer = try await fetchUser(userId: peerId) {
            titleOverride = peer.displayName.isEmpty ? "Chat" : peer.displayName
            avatarURL = peer.avatarURL
            avatarBase64 = peer.avatarBase64
            peerUserId = peerId
        }
        // Group chats keep `title` from the chat document (community name).

        var summary = try FirestoreChatMapper.chatSummary(
            from: chatDoc,
            titleOverride: titleOverride,
            avatarURL: avatarURL,
            avatarBase64: avatarBase64,
            peerUserId: peerUserId,
            isMuted: FirestoreChatMapper.isMutedChatRef(refData)
        )

        // Prefer ref timestamps when chat doc is missing lastMessageAt.
        if summary.lastMessageAt == nil {
            summary.lastMessageAt = (refData["lastMessageAt"] as? Timestamp)?.dateValue()
        }
        if summary.lastMessageText == nil {
            summary.lastMessageText = refData["lastMessageText"] as? String
        }

        return summary
    }

    private func updateOwnChatRef(chatId: String, data: [String: Any]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreChatError.notAuthenticated
        }

        try await db.collection(usersCollection)
            .document(userId)
            .collection(chatRefsCollection)
            .document(chatId)
            .setData(data, merge: true)
    }

    private func ownChatRefData(userId: String, chatId: String) async throws -> [String: Any] {
        let snapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection(chatRefsCollection)
            .document(chatId)
            .getDocument()
        return snapshot.data() ?? [:]
    }

    private func ownClearedAt(userId: String, chatId: String) async throws -> Date? {
        let data = try await ownChatRefData(userId: userId, chatId: chatId)
        return FirestoreChatMapper.clearedAt(from: data)
    }

    private static func isVisibleAfterClear(_ message: Message, clearedAt: Date?) -> Bool {
        guard let clearedAt else { return true }
        return message.createdAt > clearedAt
    }

    /// Ensures the current user is listed as a participant and has a chatRef.
    /// Does **not** set `type` / `title` — those are owned by createDirect/createGroup.
    /// Uses merge + arrayUnion only — never reads the chat doc first, because
    /// Firestore read rules deny non-participants on existing chats.
    private func ensureChatAccess(chatId: String, senderId: String) async throws {
        let chatRef = db.collection(chatsCollection).document(chatId)
        try await chatRef.setData(
            [
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

    private func fetchCommunityName(communityId: String) async throws -> String {
        let document = try await db.collection(communitiesCollection).document(communityId).getDocument()
        let name = (document.data()?["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return "Group Chat"
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

    /// Firestore allows max 500 writes per batch — chunk to stay under the limit.
    private static let firestoreBatchLimit = 450

    private func ensureChatRefsExist(
        chatId: String,
        participantIds: [String],
        lastMessageText: String?,
        lastMessageAt: Date
    ) async throws {
        let payload = FirestoreChatMapper.chatRefData(
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt
        )
        let uniqueIds = Array(Set(participantIds))
        var index = 0
        while index < uniqueIds.count {
            let end = min(index + Self.firestoreBatchLimit, uniqueIds.count)
            let chunk = uniqueIds[index..<end]
            let batch = db.batch()
            for participantId in chunk {
                let ref = db.collection(usersCollection)
                    .document(participantId)
                    .collection(chatRefsCollection)
                    .document(chatId)
                batch.setData(payload, forDocument: ref, merge: true)
            }
            try await batch.commit()
            index = end
        }
    }
}
