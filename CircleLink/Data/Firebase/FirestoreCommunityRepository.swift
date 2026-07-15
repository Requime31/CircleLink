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
        let memberSnapshot = try await db.collection(communitiesCollection)
            .document(communityId)
            .collection(membersCollection)
            .getDocuments()

        let userIds = memberSnapshot.documents.map(\.documentID)
        guard !userIds.isEmpty else { return [] }

        var users: [User] = []
        users.reserveCapacity(userIds.count)

        for userId in userIds {
            let document = try await db.collection(usersCollection).document(userId).getDocument()
            if document.exists {
                users.append(try FirestoreUserMapper.user(from: document))
            }
        }

        return users.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func join(communityId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }

        let communityRef = db.collection(communitiesCollection).document(communityId)
        let memberRef = communityRef.collection(membersCollection).document(userId)

        let memberDoc = try await memberRef.getDocument()
        if memberDoc.exists {
            return
        }

        let communityDoc = try await communityRef.getDocument()
        guard communityDoc.exists else {
            throw FirestoreCommunityError.communityNotFound
        }

        let batch = db.batch()
        batch.setData(FirestoreCommunityMapper.memberData(), forDocument: memberRef)
        batch.updateData(["memberCount": FieldValue.increment(Int64(1))], forDocument: communityRef)
        try await batch.commit()
    }

    func leave(communityId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreCommunityError.notAuthenticated
        }

        let communityRef = db.collection(communitiesCollection).document(communityId)
        let memberRef = communityRef.collection(membersCollection).document(userId)

        let memberDoc = try await memberRef.getDocument()
        guard memberDoc.exists else {
            return
        }

        let batch = db.batch()
        batch.deleteDocument(memberRef)
        batch.updateData(["memberCount": FieldValue.increment(Int64(-1))], forDocument: communityRef)
        try await batch.commit()
    }
}
