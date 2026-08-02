import Foundation

/// Thin facade over internal chat stores. ViewModels keep depending on `ChatRepository` only.
final class FirestoreChatRepository: ChatRepository, @unchecked Sendable {
    private let listStore: FirestoreChatListStore
    private let messagesStore: FirestoreChatMessagesStore
    private let membershipStore: FirestoreChatMembershipStore
    private let liveMessagesSource: FirestoreChatLiveMessagesSource

    init(imageStorage: ChatImageStorage) {
        let support = FirestoreChatSupport()
        self.listStore = FirestoreChatListStore(support: support)
        self.messagesStore = FirestoreChatMessagesStore(support: support, imageStorage: imageStorage)
        self.membershipStore = FirestoreChatMembershipStore(support: support)
        self.liveMessagesSource = FirestoreChatLiveMessagesSource(support: support)
    }

    // MARK: - ChatRepository

    func fetchChats() async throws -> [ChatSummary] {
        try await listStore.fetchChats()
    }

    func fetchHiddenChats() async throws -> [ChatSummary] {
        try await listStore.fetchHiddenChats()
    }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        try await listStore.fetchOrganizedChats()
    }

    func setChatMuted(chatId: String, muted: Bool) async throws {
        try await listStore.setChatMuted(chatId: chatId, muted: muted)
    }

    func hideChat(chatId: String) async throws {
        try await listStore.hideChat(chatId: chatId)
    }

    func unhideChat(chatId: String) async throws {
        try await listStore.unhideChat(chatId: chatId)
    }

    func fetchChatThreadMetadata(chatId: String) async throws -> ChatThreadMetadata {
        try await listStore.fetchChatThreadMetadata(chatId: chatId)
    }

    func fetchChatInfo(chatId: String) async throws -> ChatInfo {
        try await listStore.fetchChatInfo(chatId: chatId)
    }

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] {
        try await messagesStore.fetchMessages(chatId: chatId, limit: limit, before: before)
    }

    func sendMessage(
        chatId: String,
        text: String?,
        image: Data?,
        clientMessageId: String
    ) async throws {
        try await messagesStore.sendMessage(
            chatId: chatId,
            text: text,
            image: image,
            clientMessageId: clientMessageId
        )
    }

    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        liveMessagesSource.observeLiveMessages(chatId: chatId)
    }

    func createDirectChat(with userId: String) async throws -> String {
        try await membershipStore.createDirectChat(with: userId)
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        try await membershipStore.createGroupChat(
            communityId: communityId,
            participantIds: participantIds
        )
    }

    func leaveChat(chatId: String) async throws {
        try await membershipStore.leaveChat(chatId: chatId)
    }

    func leaveGroupChat(communityId: String) async throws {
        try await membershipStore.leaveGroupChat(communityId: communityId)
    }
}
