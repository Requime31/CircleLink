import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreCommunityError: LocalizedError {
    case notAuthenticated
    case communityNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to join communities."
        case .communityNotFound:
            return "Community could not be found."
        case .invalidData:
            return "Community data is invalid."
        }
    }
}

final class FirestoreCommunityRepository: CommunityRepository, @unchecked Sendable {
    private let communitiesCollection = "communities"
    private let membersCollection = "members"
    private let usersCollection = "users"

    private var db: Firestore { Firestore.firestore() }

    func fetchCommunities() async throws -> [Community] {
        let snapshot = try await db.collection(communitiesCollection).getDocuments()
        return try snapshot.documents
            .map { try FirestoreCommunityMapper.community(from: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func fetchMembers(communityId: String) async throws -> [User] {
        // Heal orphans + sync count here (detail path), not on every list fetch.
        try await reconcileMembership(communityId: communityId)
    }

    func join(communityId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }

        let communityRef = db.collection(communitiesCollection).document(communityId)
        let memberRef = communityRef.collection(membersCollection).document(userId)

        // Same RMW pattern as leave — avoids racing absolute leave writes against increment.
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let memberSnapshot: DocumentSnapshot
                do {
                    memberSnapshot = try transaction.getDocument(memberRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                if memberSnapshot.exists {
                    return nil
                }

                let communitySnapshot: DocumentSnapshot
                do {
                    communitySnapshot = try transaction.getDocument(communityRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                guard communitySnapshot.exists else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreCommunityRepository",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: FirestoreCommunityError.communityNotFound.localizedDescription]
                    )
                    return nil
                }

                let currentCount = FirestoreCommunityMapper.memberCount(from: communitySnapshot.data() ?? [:])
                transaction.setData(FirestoreCommunityMapper.memberData(), forDocument: memberRef)
                transaction.updateData(["memberCount": currentCount + 1], forDocument: communityRef)
                return nil
            }
        } catch {
            if (error as NSError).domain == "FirestoreCommunityRepository" {
                throw FirestoreCommunityError.communityNotFound
            }
            throw error
        }
    }

    func leave(communityId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }

        let communityRef = db.collection(communitiesCollection).document(communityId)
        let memberRef = communityRef.collection(membersCollection).document(userId)

        // Transaction: idempotent leave + clamp memberCount at 0 (increment(-1) can go negative).
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let memberSnapshot: DocumentSnapshot
            do {
                memberSnapshot = try transaction.getDocument(memberRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard memberSnapshot.exists else {
                return nil
            }

            let communitySnapshot: DocumentSnapshot
            do {
                communitySnapshot = try transaction.getDocument(communityRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let currentCount = FirestoreCommunityMapper.memberCount(from: communitySnapshot.data() ?? [:])
            let nextCount = max(0, currentCount - 1)

            transaction.deleteDocument(memberRef)
            if communitySnapshot.exists {
                transaction.updateData(["memberCount": nextCount], forDocument: communityRef)
            }
            return nil
        }
    }

    // MARK: - Membership reconcile

    /// Removes memberships whose user profile no longer exists, syncs `memberCount`,
    /// and returns the remaining real members (single pass — no double user fetch).
    private func reconcileMembership(communityId: String) async throws -> [User] {
        let communityRef = db.collection(communitiesCollection).document(communityId)
        let memberSnapshot = try await communityRef.collection(membersCollection).getDocuments()

        var users: [User] = []
        users.reserveCapacity(memberSnapshot.documents.count)
        var orphanRefs: [DocumentReference] = []

        for memberDoc in memberSnapshot.documents {
            let userDoc = try await db.collection(usersCollection)
                .document(memberDoc.documentID)
                .getDocument()

            if userDoc.exists {
                users.append(try FirestoreUserMapper.user(from: userDoc))
            } else {
                orphanRefs.append(memberDoc.reference)
            }
        }

        // Best-effort: delete orphans (rules allow delete when user doc is gone).
        if !orphanRefs.isEmpty {
            do {
                let batch = db.batch()
                for ref in orphanRefs {
                    batch.deleteDocument(ref)
                }
                try await batch.commit()
            } catch {
                // Count sync below still corrects the UI even if orphan delete is denied.
            }
        }

        let validCount = users.count
        let communityDoc = try await communityRef.getDocument()
        let storedCount = FirestoreCommunityMapper.memberCount(from: communityDoc.data() ?? [:])
        if communityDoc.exists, storedCount != validCount {
            try await communityRef.updateData(["memberCount": validCount])
        }

        return users.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
