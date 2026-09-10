import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Firestore owns retries. A desired state (never a toggle) makes retries idempotent.
final class FirestorePostLikeService: PostLikeService, @unchecked Sendable {
    private var db: Firestore { Firestore.firestore() }

    func setLiked(_ liked: Bool, post: PostReference, userId: String) async throws -> PostLikeSnapshot {
        // Rules may evaluate a stale transaction against a concurrent commit before the
        // precondition reports ABORTED. Re-read in a bounded retry; authorization is never bypassed.
        for attempt in 0..<4 {
            do { return try await commit(liked, post: post, userId: userId) }
            catch {
                let failure = error as NSError
                guard attempt < 3, failure.domain == FirestoreErrorDomain,
                      failure.code == FirestoreErrorCode.permissionDenied.rawValue else { throw error }
                try await Task.sleep(for: .milliseconds(100 * (attempt + 1)))
            }
        }
        throw FirestoreProfilePostError.invalidData
    }

    private func commit(_ liked: Bool, post: PostReference, userId: String) async throws -> PostLikeSnapshot {
        guard Auth.auth().currentUser?.uid == userId else { throw FirestoreProfilePostError.notAuthenticated }
        let parent = db.document(post.path)
        let like = parent.collection("likes").document(userId)
        let result = try await db.runTransaction { transaction, errorPointer in
            do {
                let postDocument = try transaction.getDocument(parent)
                let likeDocument = try transaction.getDocument(like)
                guard postDocument.exists else { throw FirestoreProfilePostError.invalidData }
                let count = postDocument.data()?["likeCount"] as? Int ?? 0
                guard likeDocument.exists != liked else { return count }
                guard count >= 0, liked || count > 0 else { throw FirestoreProfilePostError.invalidData }
                if liked {
                    transaction.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: like)
                } else {
                    transaction.deleteDocument(like)
                }
                transaction.updateData(["likeCount": FieldValue.increment(Int64(liked ? 1 : -1))], forDocument: parent)
                return count + (liked ? 1 : -1)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        return PostLikeSnapshot(count: result as? Int ?? 0, isLiked: liked)
    }

    func observeCount(post: PostReference) -> AsyncThrowingStream<Int?, Error> {
        AsyncThrowingStream { continuation in
            let registration = db.document(post.path).addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                continuation.yield(snapshot.exists ? max(0, snapshot.data()?["likeCount"] as? Int ?? 0) : nil)
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observeLike(post: PostReference, userId: String) -> AsyncThrowingStream<Bool, Error> {
        AsyncThrowingStream { continuation in
            let registration = db.document(post.path).collection("likes").document(userId).addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                continuation.yield(snapshot.exists)
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func canNavigate(userId: String, viewerId: String) async throws -> Bool {
        do {
            _ = try await db.document("users/\(userId)/profileAccess/\(viewerId)").getDocument(source: .server)
            return true
        } catch {
            let error = error as NSError
            if error.domain == FirestoreErrorDomain && error.code == FirestoreErrorCode.permissionDenied.rawValue { return false }
            throw error
        }
    }

    func likerIds(post: PostReference, after: String?, limit: Int) async throws -> [String] {
        var query: Query = db.document(post.path).collection("likes")
            .order(by: FieldPath.documentID()).limit(to: min(50, max(1, limit)))
        if let after { query = query.start(after: [after]) }
        return try await query.getDocuments().documents.map(\.documentID)
    }
}
