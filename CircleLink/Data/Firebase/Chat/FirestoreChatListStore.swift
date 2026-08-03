import FirebaseFirestore
import Foundation

/// Chat list, mute/hide prefs, and chat info (read + per-user chatRef flags).
final class FirestoreChatListStore: @unchecked Sendable {
    private let support: FirestoreChatSupport

    /// Max concurrent chat-document reads while building the list.
    private static let chatDocConcurrencyLimit = 12
    /// Firestore `in` queries accept at most 30 document ids.
    private static let userBatchSize = 30

    init(support: FirestoreChatSupport) {
        self.support = support
    }

    func fetchChats() async throws -> [ChatSummary] {
        try await fetchOrganizedChats().visible
    }

    func fetchHiddenChats() async throws -> [ChatSummary] {
        try await fetchOrganizedChats().hidden
    }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        let userId = try support.requireCurrentUserId()

        // Soft limit covers active + hidden; hidden are filtered client-side.
        let refsSnapshot = try await support.db.collection(support.usersCollection)
            .document(userId)
            .collection(support.chatRefsCollection)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 100)
            .getDocuments()

        let refs: [(chatId: String, refData: [String: Any])] = refsSnapshot.documents.map {
            ($0.documentID, $0.data())
        }

        // Batching strategy:
        // 1) Load chat docs concurrently (bounded TaskGroup) instead of serial N gets.
        // 2) Collect direct-chat peer ids, then batch-load users with `in` chunks (≤30).
        // Partial-results policy (unchanged): missing chat docs are skipped; a thrown
        // Firestore error fails the whole load so the UI can show retry.
        let chatDocs = try await fetchChatDocuments(chatIds: refs.map(\.chatId))
        let peerIds = peerUserIds(from: chatDocs, currentUserId: userId)
        let peersById = try await fetchUsers(userIds: peerIds)

        var visible: [ChatSummary] = []
        var hidden: [ChatSummary] = []
        visible.reserveCapacity(refs.count)
        hidden.reserveCapacity(8)

        for ref in refs {
            guard let chatDoc = chatDocs[ref.chatId] else { continue }
            guard let summary = makeSummary(
                chatDoc: chatDoc,
                refData: ref.refData,
                currentUserId: userId,
                peersById: peersById
            ) else { continue }

            if FirestoreChatMapper.isHiddenChatRef(ref.refData) {
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

    /// Chat doc only — used by deep links / open-chat when the list VM is not loaded.
    func fetchChatThreadMetadata(chatId: String) async throws -> ChatThreadMetadata {
        let data = try await fetchChatDocumentData(chatId: chatId)
        return Self.threadMetadata(from: data)
    }

    func fetchChatInfo(chatId: String) async throws -> ChatInfo {
        let data = try await fetchChatDocumentData(chatId: chatId)
        let metadata = Self.threadMetadata(from: data)
        let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue
        let type = ChatType(rawValue: typeRaw) ?? .direct
        let participantIds = FirestoreChatMapper.participantIds(from: data)
        let usersById = try await fetchUsers(userIds: participantIds)
        let participants = participantIds.compactMap { usersById[$0] }

        return ChatInfo(
            id: chatId,
            type: type,
            title: metadata.title,
            communityId: metadata.communityId,
            participants: participants
        )
    }

    private func fetchChatDocumentData(chatId: String) async throws -> [String: Any] {
        _ = try support.requireCurrentUserId()

        let chatDoc = try await support.db.collection(support.chatsCollection).document(chatId).getDocument()
        guard chatDoc.exists else {
            throw FirestoreChatError.chatNotFound
        }
        return chatDoc.data() ?? [:]
    }

    private static func threadMetadata(from data: [String: Any]) -> ChatThreadMetadata {
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
        return ChatThreadMetadata(title: resolvedTitle, communityId: resolvedCommunityId)
    }

    // MARK: - Batched list helpers

    private func fetchChatDocuments(
        chatIds: [String]
    ) async throws -> [String: DocumentSnapshot] {
        guard !chatIds.isEmpty else { return [:] }

        var results: [String: DocumentSnapshot] = [:]
        results.reserveCapacity(chatIds.count)

        try await withThrowingTaskGroup(of: (String, DocumentSnapshot?).self) { group in
            var iterator = chatIds.makeIterator()
            var inFlight = 0

            func enqueueNext() {
                guard let chatId = iterator.next() else { return }
                inFlight += 1
                group.addTask { [support] in
                    let doc = try await support.db
                        .collection(support.chatsCollection)
                        .document(chatId)
                        .getDocument()
                    return (chatId, doc.exists ? doc : nil)
                }
            }

            for _ in 0..<min(Self.chatDocConcurrencyLimit, chatIds.count) {
                enqueueNext()
            }

            while let (chatId, doc) = try await group.next() {
                inFlight -= 1
                if let doc {
                    results[chatId] = doc
                }
                enqueueNext()
                _ = inFlight
            }
        }

        return results
    }

    private func peerUserIds(
        from chatDocs: [String: DocumentSnapshot],
        currentUserId: String
    ) -> [String] {
        var peerIds = Set<String>()
        for doc in chatDocs.values {
            let data = doc.data() ?? [:]
            let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue
            let type = ChatType(rawValue: typeRaw) ?? .direct
            guard type == .direct else { continue }
            let participants = FirestoreChatMapper.participantIds(from: data)
            if let peerId = participants.first(where: { $0 != currentUserId }) {
                peerIds.insert(peerId)
            }
        }
        return Array(peerIds)
    }

    private func fetchUsers(userIds: [String]) async throws -> [String: User] {
        let unique = Array(Set(userIds.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        var result: [String: User] = [:]
        result.reserveCapacity(unique.count)

        var start = 0
        while start < unique.count {
            let end = min(start + Self.userBatchSize, unique.count)
            let chunk = Array(unique[start..<end])
            let snapshot = try await support.db.collection(support.usersCollection)
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents where document.exists {
                if let user = try? FirestoreUserMapper.user(from: document) {
                    result[user.id] = user
                }
            }
            start = end
        }

        return result
    }

    private func makeSummary(
        chatDoc: DocumentSnapshot,
        refData: [String: Any],
        currentUserId: String,
        peersById: [String: User]
    ) -> ChatSummary? {
        let data = chatDoc.data() ?? [:]
        let typeRaw = data["type"] as? String ?? ChatType.direct.rawValue
        let type = ChatType(rawValue: typeRaw) ?? .direct
        let participants = FirestoreChatMapper.participantIds(from: data)

        var titleOverride: String?
        var avatarURL: URL?
        var avatarBase64: String?
        var peerUserId: String?

        if type == .direct,
           let peerId = participants.first(where: { $0 != currentUserId }) {
            peerUserId = peerId
            if let peer = peersById[peerId] {
                titleOverride = peer.displayName.isEmpty ? "Chat" : peer.displayName
                avatarURL = peer.avatarURL
                avatarBase64 = peer.avatarBase64
            }
        }
        // Group chats keep `title` from the chat document (community name).

        do {
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
        } catch {
            return nil
        }
    }

    private func updateOwnChatRef(chatId: String, data: [String: Any]) async throws {
        let userId = try support.requireCurrentUserId()

        try await support.db.collection(support.usersCollection)
            .document(userId)
            .collection(support.chatRefsCollection)
            .document(chatId)
            .setData(data, merge: true)
    }
}
