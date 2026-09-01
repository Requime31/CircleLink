import Foundation

final class StubChatRepository: ChatRepository, @unchecked Sendable {
    func fetchChats() async throws -> [ChatSummary] { [] }

    func fetchHiddenChats() async throws -> [ChatSummary] { [] }

    func fetchOrganizedChats() async throws -> OrganizedChats {
        OrganizedChats(visible: [], hidden: [])
    }

    func fetchChatInfo(chatId: String) async throws -> ChatInfo {
        ChatInfo(
            id: chatId,
            type: .direct,
            title: "Stub Chat",
            communityId: nil,
            participants: [],
            isMuted: false,
            clearedAt: nil
        )
    }

    func fetchMessages(chatId: String, limit: Int, before: MessagePageCursor?) async throws -> [Message] { [] }

    func fetchChatMedia(chatId: String, limit: Int, before: MessagePageCursor?) async throws -> [Message] { [] }

    func sendMessage(chatId: String, text: String?, image: Data?, clientMessageId: String) async throws {}

    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { _ in }
    }

    func createDirectChat(with userId: String) async throws -> String {
        "stub-chat-\(userId)"
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        "group_\(communityId)"
    }

    func leaveChat(chatId: String) async throws {}

    func leaveGroupChat(communityId: String) async throws {}

    func setChatMuted(chatId: String, muted: Bool) async throws {}

    func setChatPinned(chatId: String, pinned: Bool) async throws {}

    func reorderPinnedChats(chatIds: [String]) async throws {}

    func hideChat(chatId: String) async throws {}

    func unhideChat(chatId: String) async throws {}

    func clearChatHistory(chatId: String) async throws {}

    func deleteDirectChat(chatId: String) async throws {}
}
