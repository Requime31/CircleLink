import Foundation

nonisolated struct ConnectionRequest: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let communityId: String
    var status: ConnectionStatus
    let createdAt: Date
}
