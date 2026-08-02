import Foundation

final class StubChatImageStorage: ChatImageStorage, @unchecked Sendable {
    func uploadChatImage(data: Data, chatId: String, messageId: String) async throws -> URL {
        guard let url = URL(string: "https://example.com/chat/\(chatId)/\(messageId).jpg") else {
            throw URLError(.badURL)
        }
        return url
    }
}
