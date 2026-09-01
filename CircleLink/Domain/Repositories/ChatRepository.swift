import Foundation

/// Visible + hidden buckets from one chatRefs pass (avoids a second round-trip).
struct OrganizedChats: Sendable {
    let visible: [ChatSummary]
    let hidden: [ChatSummary]
}

/// Stable Firestore pagination cursor. The document id breaks ties when
/// multiple messages share the same server timestamp.
struct MessagePageCursor: Equatable, Sendable {
    let createdAt: Date
    let messageId: String

    init(createdAt: Date, messageId: String) {
        self.createdAt = createdAt
        self.messageId = messageId
    }

    init(message: Message) {
        self.init(createdAt: message.createdAt, messageId: message.id)
    }
}

enum ChatPinningError: LocalizedError, Equatable {
    case duplicateChatIDs
    case unknownChat(String)
    case hiddenChat(String)
    case incompletePinnedSet
    case notParticipant(String)

    var errorDescription: String? {
        switch self {
        case .duplicateChatIDs:
            return "Pinned chat order contains duplicates."
        case .unknownChat:
            return "One or more chats are no longer available."
        case .hiddenChat:
            return "Hidden chats cannot be pinned."
        case .incompletePinnedSet:
            return "Pinned chat order must include every pinned chat."
        case .notParticipant:
            return "You no longer have access to one or more chats."
        }
    }
}

protocol ChatRepository: Sendable {
    /// Non-hidden chats for the main list.
    func fetchChats() async throws -> [ChatSummary]
    /// Soft-hidden chats for the Hidden chats screen.
    func fetchHiddenChats() async throws -> [ChatSummary]
    /// One Firestore pass → both lists (preferred for the Chats tab).
    func fetchOrganizedChats() async throws -> OrganizedChats
    /// Loads chat metadata + participant profiles for Chat Info / Members.
    func fetchChatInfo(chatId: String) async throws -> ChatInfo
    /// History for the current user. Respects per-user `clearedAt` watermark.
    func fetchMessages(chatId: String, limit: Int, before: MessagePageCursor?) async throws -> [Message]
    /// Messages with images only (newest first page). Respects `clearedAt`.
    func fetchChatMedia(chatId: String, limit: Int, before: MessagePageCursor?) async throws -> [Message]
    func sendMessage(chatId: String, text: String?, image: Data?, clientMessageId: String) async throws
    func observeLiveMessages(chatId: String) -> AsyncStream<Message>
    func createDirectChat(with userId: String) async throws -> String
    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String
    /// Leaves this chat only (removes self from `participantIds` + deletes own `chatRef`).
    /// Does **not** leave the community. Use for **group** chats.
    func leaveChat(chatId: String) async throws
    /// Removes the current user from the community group chat (participantIds + chatRef).
    /// Call **before** leaving the community — group write rules require membership.
    func leaveGroupChat(communityId: String) async throws
    /// Push-only mute for the current user. Idempotent.
    func setChatMuted(chatId: String, muted: Bool) async throws
    /// Owner-only, idempotent pin metadata. Unpin also removes the manual rank.
    func setChatPinned(chatId: String, pinned: Bool) async throws
    /// Atomically stores a complete ordered set of the owner's visible pinned chats.
    func reorderPinnedChats(chatIds: [String]) async throws
    /// Soft-hide for the current user only. Does not leave membership / wipe history.
    func hideChat(chatId: String) async throws
    /// Restores a soft-hidden chat to the main list. Idempotent.
    func unhideChat(chatId: String) async throws
    /// Clears visible history for the current user only (`chatRefs.clearedAt`). Does not delete messages.
    func clearChatHistory(chatId: String) async throws
    /// DM only: deletes own `chatRef` so the chat leaves the list. Does **not** remove peer membership.
    func deleteDirectChat(chatId: String) async throws
}
