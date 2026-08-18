import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirestoreCommunityPostRepository: CommunityPostRepository, @unchecked Sendable {
    private let imageStorage: CommunityImageStorage
    private var db: Firestore { Firestore.firestore() }

    init(imageStorage: CommunityImageStorage) { self.imageStorage = imageStorage }

    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost] {
        var query: Query = postsRef(communityId).order(by: "createdAt", descending: true).limit(to: max(1, limit))
        if let before { query = query.start(after: [Timestamp(date: before)]) }
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { try FirestoreCommunityPostMapper.post(from: $0, communityId: communityId) }
    }

    func createPost(communityId: String, postId: String, text: String?, image: Data?) async throws -> CommunityPost {
        guard let userId = Auth.auth().currentUser?.uid else { throw FirestoreProfilePostError.notAuthenticated }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed?.isEmpty == false || image != nil else { throw FirestoreProfilePostError.emptyContent }
        guard trimmed?.count ?? 0 <= FirestoreCommunityPostMapper.maxTextLength else { throw FirestoreProfilePostError.textTooLong }
        let createdAt = Date()
        let imageURL = try await upload(image, communityId: communityId, postId: postId)
        do {
            try await postsRef(communityId).document(postId).setData(
                FirestoreCommunityPostMapper.data(authorId: userId, text: trimmed, imageURL: imageURL, createdAt: createdAt)
            )
        } catch {
            if imageURL != nil { try? await imageStorage.deletePostImage(communityId: communityId, postId: postId) }
            throw error
        }
        return CommunityPost(id: postId, communityId: communityId, authorId: userId, text: trimmed, imageURL: imageURL, createdAt: createdAt)
    }

    func updatePost(_ post: CommunityPost, text: String?, image: Data?, removeImage: Bool) async throws -> CommunityPost {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed?.count ?? 0 <= FirestoreCommunityPostMapper.maxTextLength else { throw FirestoreProfilePostError.textTooLong }
        var imageURL = post.imageURL
        if let image { imageURL = try await upload(image, communityId: post.communityId, postId: post.id) }
        else if removeImage { imageURL = nil }
        guard trimmed?.isEmpty == false || imageURL != nil else { throw FirestoreProfilePostError.emptyContent }
        var updates: [String: Any] = ["text": trimmed?.isEmpty == false ? trimmed as Any : FieldValue.delete()]
        updates["imageURL"] = imageURL?.absoluteString as Any? ?? FieldValue.delete()
        try await postsRef(post.communityId).document(post.id).updateData(updates)
        if removeImage, image == nil, post.imageURL != nil { try? await imageStorage.deletePostImage(communityId: post.communityId, postId: post.id) }
        return CommunityPost(id: post.id, communityId: post.communityId, authorId: post.authorId, text: trimmed?.isEmpty == false ? trimmed : nil, imageURL: imageURL, createdAt: post.createdAt)
    }

    func deletePost(_ post: CommunityPost) async throws {
        try await postsRef(post.communityId).document(post.id).delete()
        if post.imageURL != nil { try? await imageStorage.deletePostImage(communityId: post.communityId, postId: post.id) }
    }

    private func upload(_ image: Data?, communityId: String, postId: String) async throws -> URL? {
        guard let image else { return nil }
        return try await imageStorage.uploadPostImage(data: ImageCompressor.compressForChat(image), communityId: communityId, postId: postId)
    }

    private func postsRef(_ communityId: String) -> CollectionReference {
        db.collection("communities").document(communityId).collection("posts")
    }
}
