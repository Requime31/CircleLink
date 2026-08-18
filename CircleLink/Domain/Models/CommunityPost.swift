import Foundation

struct CommunityPost: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let communityId: String
    let authorId: String
    var text: String?
    var imageURL: URL?
    let createdAt: Date
}
