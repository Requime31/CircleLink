import Foundation

final class StubProfilePostRepository: ProfilePostRepository, @unchecked Sendable {
    private var postsByUser: [String: [ProfilePost]] = [:]
    private let stubAuthorId: String

    init(stubAuthorId: String = "stub-user") {
        self.stubAuthorId = stubAuthorId
    }

    func fetchPosts(userId: String, limit: Int, before: Date?) async throws -> [ProfilePost] {
        let sorted = (postsByUser[userId] ?? [])
            .sorted { $0.createdAt > $1.createdAt }

        let filtered: [ProfilePost]
        if let before {
            filtered = sorted.filter { $0.createdAt < before }
        } else {
            filtered = sorted
        }

        return Array(filtered.prefix(max(limit, 1)))
    }

    func fetchPostCount(userId: String) async throws -> Int {
        postsByUser[userId]?.count ?? 0
    }

    func createPost(postId: String, text: String?, image: Data?) async throws -> ProfilePost {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        guard hasText || image != nil else {
            throw FirestoreProfilePostError.emptyContent
        }

        let post = ProfilePost(
            id: postId,
            authorId: stubAuthorId,
            text: hasText ? trimmed : nil,
            imageURL: image == nil ? nil : URL(string: "https://example.com/\(postId).jpg"),
            createdAt: Date()
        )
        postsByUser[stubAuthorId, default: []].insert(post, at: 0)
        return post
    }

    func updatePost(
        _ post: ProfilePost,
        text: String?,
        image: Data?,
        removeImage: Bool
    ) async throws -> ProfilePost {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)

        var imageURL = post.imageURL
        if image != nil {
            imageURL = URL(string: "https://example.com/\(post.id).jpg")
        } else if removeImage {
            imageURL = nil
        }

        guard hasText || imageURL != nil else {
            throw FirestoreProfilePostError.emptyContent
        }

        let updated = ProfilePost(
            id: post.id,
            authorId: post.authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: post.createdAt
        )

        guard var list = postsByUser[post.authorId],
              let index = list.firstIndex(where: { $0.id == post.id }) else {
            throw FirestoreProfilePostError.invalidData
        }
        list[index] = updated
        postsByUser[post.authorId] = list
        return updated
    }

    func deletePost(_ post: ProfilePost) async throws {
        postsByUser[post.authorId]?.removeAll { $0.id == post.id }
    }
}
