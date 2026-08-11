import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreProfilePostError: LocalizedError {
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
            return "You can only manage your own posts."
        }
    }
}

final class FirestoreProfilePostRepository: ProfilePostRepository, @unchecked Sendable {
    private let usersCollection = "users"
    private let postsCollection = "profilePosts"

    private let imageStorage: ProfileImageStorage

    private var db: Firestore { Firestore.firestore() }

    init(imageStorage: ProfileImageStorage) {
        self.imageStorage = imageStorage
    }

    func fetchPosts(userId: String, limit: Int, before: Date?) async throws -> [ProfilePost] {
        var query: Query = postsRef(userId: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: max(limit, 1))

        if let before {
            query = query.start(after: [Timestamp(date: before)])
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map {
            try FirestoreProfilePostMapper.post(from: $0, authorIdFallback: userId)
        }
    }

    func fetchPostCount(userId: String) async throws -> Int {
        let aggregate = try await postsRef(userId: userId).count.getAggregation(source: .server)
        return Int(truncating: aggregate.count)
    }

    func createPost(postId: String, text: String?, image: Data?) async throws -> ProfilePost {
        guard let authorId = Auth.auth().currentUser?.uid else {
            throw FirestoreProfilePostError.notAuthenticated
        }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)
        let hasImage = image != nil

        guard hasText || hasImage else {
            throw FirestoreProfilePostError.emptyContent
        }

        if let trimmed, trimmed.count > FirestoreProfilePostMapper.maxTextLength {
            throw FirestoreProfilePostError.textTooLong
        }

        let createdAt = Date()
        var imageURL: URL?
        var didUploadImage = false

        if let image {
            let compressed = try ImageCompressor.compressForChat(image)
            imageURL = try await imageStorage.uploadProfileImage(
                data: compressed,
                userId: authorId,
                postId: postId
            )
            didUploadImage = true
        }

        let postRef = postsRef(userId: authorId).document(postId)
        let data = FirestoreProfilePostMapper.postData(
            authorId: authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: createdAt
        )

        do {
            try await postRef.setData(data)
        } catch {
            if didUploadImage {
                try? await imageStorage.deleteProfileImage(userId: authorId, postId: postId)
            }
            throw error
        }

        return ProfilePost(
            id: postId,
            authorId: authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: createdAt
        )
    }

    func updatePost(
        _ post: ProfilePost,
        text: String?,
        image: Data?,
        removeImage: Bool
    ) async throws -> ProfilePost {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreProfilePostError.notAuthenticated
        }

        guard post.authorId == uid else {
            throw FirestoreProfilePostError.notAuthor
        }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed?.isEmpty ?? true)

        if let trimmed, trimmed.count > FirestoreProfilePostMapper.maxTextLength {
            throw FirestoreProfilePostError.textTooLong
        }

        var imageURL = post.imageURL

        if let image {
            let compressed = try ImageCompressor.compressForChat(image)
            imageURL = try await imageStorage.uploadProfileImage(
                data: compressed,
                userId: uid,
                postId: post.id
            )
        } else if removeImage {
            imageURL = nil
        }

        guard hasText || imageURL != nil else {
            throw FirestoreProfilePostError.emptyContent
        }

        // Patch only mutable fields so createdAt/authorId stay byte-identical for rules.
        var updates: [String: Any] = [:]
        if hasText, let trimmed {
            updates["text"] = trimmed
        } else {
            updates["text"] = FieldValue.delete()
        }
        if let imageURL {
            updates["imageURL"] = imageURL.absoluteString
        } else {
            updates["imageURL"] = FieldValue.delete()
        }

        try await postsRef(userId: uid).document(post.id).updateData(updates)

        if removeImage, image == nil, post.imageURL != nil {
            try? await imageStorage.deleteProfileImage(userId: uid, postId: post.id)
        }

        return ProfilePost(
            id: post.id,
            authorId: post.authorId,
            text: hasText ? trimmed : nil,
            imageURL: imageURL,
            createdAt: post.createdAt
        )
    }

    func deletePost(_ post: ProfilePost) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreProfilePostError.notAuthenticated
        }

        guard post.authorId == uid else {
            throw FirestoreProfilePostError.notAuthor
        }

        try await postsRef(userId: uid).document(post.id).delete()

        if post.imageURL != nil {
            try? await imageStorage.deleteProfileImage(userId: uid, postId: post.id)
        }
    }

    private func postsRef(userId: String) -> CollectionReference {
        db.collection(usersCollection)
            .document(userId)
            .collection(postsCollection)
    }
}
