import Foundation

struct ConnectionRequest: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    /// Legacy field — older docs may still have it. New connects omit community.
    let communityId: String?
    var status: ConnectionStatus
    let createdAt: Date
}
