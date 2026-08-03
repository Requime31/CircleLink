import Foundation

/// Visible + hidden buckets from one chatRefs pass (avoids a second round-trip).
nonisolated struct OrganizedChats: Sendable {
    let visible: [ChatSummary]
    let hidden: [ChatSummary]
}

protocol ChatRepository: Sendable {
    /// Non-hidden chats for the main list.
    func fetchChats() async throws -> [ChatSummary]
    /// Soft-hidden chats for the Hidden chats screen.
    func fetchHiddenChats() async throws -> [ChatSummary]
    /// One Firestore pass → both lists (preferred for the Chats tab).
    func fetchOrganizedChats() async throws -> OrganizedChats
    /// Lightweight title + communityId for open-chat / deep links (no participant profiles).
    func fetchChatThreadMetadata(chatId: String) async throws -> ChatThreadMetadata
    /// Loads chat metadata + participant profiles for Chat Info / Members.
    func fetchChatInfo(chatId: String) async throws -> ChatInfo
    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message]
    func sendMessage(chatId: String, text: String?, image: Data?, clientMessageId: String) async throws
    /// Follow-up: migrate to AsyncThrowingStream so listener failures can reach UI state.
    /// AsyncStream currently carries messages and cancellation only.
    func observeLiveMessages(chatId: String) -> AsyncStream<Message>
    func createDirectChat(with userId: String) async throws -> String
    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String
    /// Leaves this chat only (removes self from `participantIds` + deletes own `chatRef`).
    /// Does **not** leave the community.
    func leaveChat(chatId: String) async throws
    /// Removes the current user from the community group chat (participantIds + chatRef).
    /// Call **before** leaving the community — group write rules require membership.
    func leaveGroupChat(communityId: String) async throws
    /// Push-only mute for the current user. Idempotent.
    func setChatMuted(chatId: String, muted: Bool) async throws
    /// Soft-hide for the current user only. Does not leave membership / wipe history.
    func hideChat(chatId: String) async throws
    /// Restores a soft-hidden chat to the main list. Idempotent.
    func unhideChat(chatId: String) async throws
}
