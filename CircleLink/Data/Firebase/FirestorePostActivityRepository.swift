import Foundation
import FirebaseFirestore

struct PostActivityContent {
    let community: CommunityPost?
    let profile: ProfilePost?
    let author: User
}
final class FirestorePostActivityRepository: @unchecked Sendable {
    private let users: UserRepository
    init(users: UserRepository) { self.users = users }
    func fetch(_ reference: PostReference) async throws -> PostActivityContent {
        let doc = try await Firestore.firestore().document(reference.path).getDocument()
        guard doc.exists else { throw FirestoreProfilePostError.invalidData }
        if reference.kind == .community {
            let post = try FirestoreCommunityPostMapper.post(from: doc, communityId: reference.ownerId)
            let author = try await users.fetchProfile(userId: post.authorId)
            guard author.isSociallyAvailable else { throw FirestoreProfilePostError.invalidData }
            return PostActivityContent(community: post, profile: nil, author: author)
        }
        let post = try FirestoreProfilePostMapper.post(from: doc, authorIdFallback: reference.ownerId)
        let author = try await users.fetchProfile(userId: post.authorId)
        guard author.isSociallyAvailable else { throw FirestoreProfilePostError.invalidData }
        return PostActivityContent(community: nil, profile: post, author: author)
    }
}
