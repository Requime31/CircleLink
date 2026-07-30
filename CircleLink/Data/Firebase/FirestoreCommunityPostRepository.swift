import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreCommunityPostError: LocalizedError {
    case notAuthenticated
    case invalidData
    case emptyContent
    case textTooLong
    case notAuthor

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to manage posts."
        case .invalidData:
            return "Post data is invalid."
        case .emptyContent:
            return "Add text or a photo to post."
        case .textTooLong:
            return "Post text is too long."
        case .notAuthor:
            return "You can only delete your own posts."
        }
    }
}

final class FirestoreCommunityPostRepository: CommunityPostRepository, @unchecked Sendable {
    private let communitiesCollection = "communities"
    private let postsCollection = "posts"

    private let imageStorage: CommunityImageStorage

    private var db: Firestore { Firestore.firestore() }

    init(imageStorage: CommunityImageStorage) {
        self.imageStorage = imageStorage
    }

    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost] {
        var query: Query = db.collection(communitiesCollection)
            .document(communityId)
            .collection(postsCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        if let before {
            query = query.start(after: [Timestamp(date: before)])
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map {
            try FirestoreCommunityPostMapper.post(from: $0, communityId: communityId)
        }
    }

    func createPost(
        communityId: String,
        postId: String,
        text: String?,
        image: Data?
    ) async throws -> CommunityPost {
        guard let authorId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityPostError.notAuthenticated
        }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        let hasImage = image != nil

        guard hasText || hasImage else {
            throw FirestoreCommunityPostError.emptyContent
        }

        if let trimmed, trimmed.count > FirestoreCommunityPostMapper.maxTextLength {
            throw FirestoreCommunityPostError.textTooLong
        }

        let createdAt = Date()
        var imageURL: URL?
        var didUploadImage = false

        if let image {
            let compressed = try ImageCompressor.compressForChat(image)
            imageURL = try await imageStorage.uploadCommunityImage(
                data: compressed,
                communityId: communityId,
                postId: postId
            )
            didUploadImage = true
        }

        let postRef = db.collection(communitiesCollection)
            .document(communityId)
            .collection(postsCollection)
            .document(postId)

        let data = FirestoreCommunityPostMapper.postData(
            authorId: authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: createdAt
        )

        do {
            try await postRef.setData(data)
        } catch {
            // Avoid orphan misleading posts: if doc write fails after upload, clean storage.
            if didUploadImage {
                try? await imageStorage.deleteCommunityImage(communityId: communityId, postId: postId)
            }
            throw error
        }

        return CommunityPost(
            id: postId,
            communityId: communityId,
            authorId: authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: createdAt
        )
    }

    func deletePost(_ post: CommunityPost) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityPostError.notAuthenticated
        }

        guard post.authorId == uid else {
            throw FirestoreCommunityPostError.notAuthor
        }

        try await db.collection(communitiesCollection)
            .document(post.communityId)
            .collection(postsCollection)
            .document(post.id)
            .delete()

        // Best-effort storage cleanup — Firestore delete already succeeded.
        if post.imageURL != nil {
            try? await imageStorage.deleteCommunityImage(
                communityId: post.communityId,
                postId: post.id
            )
        }
    }
}
