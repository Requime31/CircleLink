import Foundation

nonisolated struct Message: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let chatId: String
    let senderId: String
    var text: String?
    var imageURL: URL?
    let createdAt: Date
    var clientMessageId: String?
    var status: MessageStatus
}
