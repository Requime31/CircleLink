import Foundation

/// A post on a user's profile (`users/{userId}/profilePosts/{postId}`).
/// Separate from community feed posts. At least one of `text` / `imageURL` must be present.
struct ProfilePost: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let authorId: String
    var text: String?
    var imageURL: URL?
    var likeCount: Int = 0
    let createdAt: Date
    private enum CodingKeys: String, CodingKey { case id, authorId, text, imageURL, likeCount, createdAt }

    init(id: String, authorId: String, text: String?, imageURL: URL?, likeCount: Int = 0, createdAt: Date) {
        self.id = id
        self.authorId = authorId
        self.text = text
        self.imageURL = imageURL
        self.likeCount = max(0, likeCount)
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            authorId: try values.decode(String.self, forKey: .authorId),
            text: try values.decodeIfPresent(String.self, forKey: .text),
            imageURL: try values.decodeIfPresent(URL.self, forKey: .imageURL),
            likeCount: try values.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0,
            createdAt: try values.decode(Date.self, forKey: .createdAt)
        )
    }
}
