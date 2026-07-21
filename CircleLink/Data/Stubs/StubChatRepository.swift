import Foundation

final class StubChatRepository: ChatRepository, @unchecked Sendable {
    func fetchChats() async throws -> [ChatSummary] { [] }

    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message] { [] }

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

    func leaveGroupChat(communityId: String) async throws {}
}
