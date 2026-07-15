import Foundation

final class StubChatRepository: ChatRepository, @unchecked Sendable {
    func fetchChats() async throws -> [ChatSummary] { [] }

    func fetchMessages(chatId: String, limit: Int) async throws -> [Message] { [] }

    func sendMessage(chatId: String, text: String?, image: Data?) async throws {}

    func observeLiveMessages(chatId: String) -> AsyncStream<Message> {
        AsyncStream { _ in }
    }

    func createDirectChat(with userId: String) async throws -> String {
        "stub-chat-\(userId)"
    }

    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String {
        "stub-group-\(communityId)"
    }
}
