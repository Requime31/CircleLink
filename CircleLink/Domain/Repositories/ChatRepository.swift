import Foundation

protocol ChatRepository: Sendable {
    func fetchChats() async throws -> [ChatSummary]
    func fetchMessages(chatId: String, limit: Int, before: Date?) async throws -> [Message]
    func sendMessage(chatId: String, text: String?, image: Data?, clientMessageId: String) async throws
    func observeLiveMessages(chatId: String) -> AsyncStream<Message>
    func createDirectChat(with userId: String) async throws -> String
    func createGroupChat(communityId: String, participantIds: [String]) async throws -> String
    /// Removes the current user from the community group chat (participantIds + chatRef).
    /// Call **before** leaving the community — group write rules require membership.
    func leaveGroupChat(communityId: String) async throws
}
