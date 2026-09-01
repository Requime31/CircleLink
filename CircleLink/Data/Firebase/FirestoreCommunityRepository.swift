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
        try await fetchActiveMembers(communityId: communityId)
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

    func updateCoverURL(communityId: String, url: URL?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }

        let ref = db.collection(communitiesCollection).document(communityId)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists else { throw FirestoreCommunityError.communityNotFound }
        guard snapshot.data()?["createdBy"] as? String == userId else {
            throw FirestoreCommunityError.notAuthenticated
        }

        if let url {
            try await ref.updateData(["coverImageURL": url.absoluteString])
        } else {
            try await ref.updateData(["coverImageURL": FieldValue.delete()])
        }
    }

    func updateCommunityMetadata(communityId: String, name: String, description: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }
        let content = try CommunityContentPolicy.validate(name: name, description: description)
        let ref = db.collection(communitiesCollection).document(communityId)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists else { throw FirestoreCommunityError.communityNotFound }
        guard snapshot.data()?["createdBy"] as? String == userId else {
            throw FirestoreCommunityError.notAuthenticated
        }
        try await ref.updateData([
            "name": content.name,
            "description": content.description
        ])
    }

    // MARK: - Membership fetch

    /// Membership cleanup/count repair is server-owned. Clients only resolve active profiles.
    private func fetchActiveMembers(communityId: String) async throws -> [User] {
        let communityRef = db.collection(communitiesCollection).document(communityId)
        let memberSnapshot = try await communityRef.collection(membersCollection).getDocuments()

        var activeUsers: [User] = []
        activeUsers.reserveCapacity(memberSnapshot.documents.count)

        for memberDoc in memberSnapshot.documents {
            let userDoc = try await db.collection(usersCollection)
                .document(memberDoc.documentID)
                .getDocument()

            if userDoc.exists {
                let user = try FirestoreUserMapper.user(from: userDoc)
                if user.isSociallyAvailable { activeUsers.append(user) }
            }
        }

        return activeUsers.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func fetchJoinedCommunityCount() async throws -> Int {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }
        return try await fetchCommunities(forUserId: userId).count
    }

    func fetchCommunities(forUserId userId: String) async throws -> [Community] {
        // Membership lives under communities/{id}/members/{uid}. There is no reverse index yet,
        // so we check membership docs in parallel (fine while community count stays small).
        let communities = try await fetchCommunities()
        guard !communities.isEmpty else { return [] }

        return await withTaskGroup(of: Community?.self, returning: [Community].self) { group in
            for community in communities {
                group.addTask {
                    let memberDoc = try? await self.db
                        .collection(self.communitiesCollection)
                        .document(community.id)
                        .collection(self.membersCollection)
                        .document(userId)
                        .getDocument()
                    return memberDoc?.exists == true ? community : nil
                }
            }

            var joined: [Community] = []
            for await community in group {
                if let community {
                    joined.append(community)
                }
            }
            return joined.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    func createCommunity(
        name: String,
        description: String,
        interestTag: String
    ) async throws -> Community {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }

        let content = try CommunityContentPolicy.validate(name: name, description: description)
        let trimmedTag = interestTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else {
            throw FirestoreCommunityError.invalidData
        }

        let communityRef = db.collection(communitiesCollection).document()
        let memberRef = communityRef.collection(membersCollection).document(userId)

        let batch = db.batch()
        batch.setData(
            FirestoreCommunityMapper.createCommunityData(
                name: content.name,
                description: content.description,
                interestTag: trimmedTag,
                createdBy: userId
            ),
            forDocument: communityRef
        )
        batch.setData(
            FirestoreCommunityMapper.memberData(role: .admin),
            forDocument: memberRef
        )
        try await batch.commit()

        return Community(
            id: communityRef.documentID,
            name: content.name,
            description: content.description,
            interestTag: trimmedTag,
            memberCount: 1,
            createdAt: Date(),
            creatorId: userId
        )
    }
}
