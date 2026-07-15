import Foundation

protocol ChatRepository: Sendable {
    func fetchChats() async throws -> [ChatSummary]
    func fetchMessages(chatId: String, limit: Int) async throws -> [Message]
    func sendMessage(chatId: String, text: String?, image: Data?) async throws
    func observeLiveMessages(chatId: String) -> AsyncStream<Message>
    func createDirectChat(with userId: String) async throws -> String
    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String
}
