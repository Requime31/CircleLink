import Foundation

struct Community: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
    let interestTag: String
    var memberCount: Int
    let coverImageURL: URL?
    let createdAt: Date?
    let creatorId: String?

    init(
        id: String,
        name: String,
        description: String,
        interestTag: String,
        memberCount: Int,
        coverImageURL: URL? = nil,
        createdAt: Date? = nil,
        creatorId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.interestTag = interestTag
        self.memberCount = memberCount
        self.coverImageURL = coverImageURL
        self.createdAt = createdAt
        self.creatorId = creatorId
    }
}
