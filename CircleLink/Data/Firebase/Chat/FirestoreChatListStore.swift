import FirebaseFirestore
import Foundation

/// Chat list, mute/hide prefs, and chat info (read + per-user chatRef flags).
final class FirestoreChatListStore: @unchecked Sendable {
    private let support: FirestoreChatSupport

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

        var participants: [User] = []
        participants.reserveCapacity(participantIds.count)
        for participantId in participantIds {
            if let user = try await support.fetchUser(userId: participantId) {
                participants.append(user)
            }
        }

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

    // MARK: - Private

    private func makeSummary(
        chatId: String,
        refData: [String: Any],
        currentUserId: String
    ) async throws -> ChatSummary? {
        let chatDoc = try await support.db.collection(support.chatsCollection).document(chatId).getDocument()
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
           let peer = try await support.fetchUser(userId: peerId) {
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
        let userId = try support.requireCurrentUserId()

        try await support.db.collection(support.usersCollection)
            .document(userId)
            .collection(support.chatRefsCollection)
            .document(chatId)
            .setData(data, merge: true)
    }
}
