import Foundation

struct ChatSummary: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let type: ChatType
    let title: String
    var lastMessageText: String?
    var lastMessageAt: Date?
    var unreadCount: Int
}
