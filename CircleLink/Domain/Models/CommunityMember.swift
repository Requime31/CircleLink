import Foundation

struct CommunityMember: Codable, Equatable, Sendable {
    let userId: String
    let joinedAt: Date
    let role: MemberRole
}
