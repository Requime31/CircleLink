import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreConnectionError: LocalizedError {
    case notAuthenticated
    case invalidPeer
    case duplicateRequest
    case requestNotFound
    case notRecipient
    case notParticipant
    case invalidStatusTransition

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to connect."
        case .invalidPeer:
            return "Cannot connect with yourself."
        case .duplicateRequest:
            return "A connection request already exists."
        case .requestNotFound:
            return "Connection request not found."
        case .notRecipient:
            return "Only the recipient can respond to this request."
        case .notParticipant:
            return "Only people in this connection can change it."
        case .invalidStatusTransition:
            return "This request can no longer be updated."
        }
    }
}

final class FirestoreConnectionRepository: ConnectionRepository, @unchecked Sendable {
    private let requestsCollection = "connectionRequests"
    private let usersCollection = "users"

    private var db: Firestore { Firestore.firestore() }

    func fetchCandidates() async throws -> [User] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        let excluded = try await connectedOrPendingPeerIds(for: currentUserId)
        let snapshot = try await db.collection(usersCollection).getDocuments()

        var candidates: [User] = []
        candidates.reserveCapacity(snapshot.documents.count)

        for document in snapshot.documents {
            let userId = document.documentID
            guard userId != currentUserId, !excluded.contains(userId) else { continue }
            do {
                candidates.append(try FirestoreUserMapper.user(from: document))
            } catch {
                // Skip corrupt profiles so one bad doc cannot empty Discover.
                continue
            }
        }

        return candidates
    }

    func sendConnect(to userId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        guard currentUserId != userId else {
            throw FirestoreConnectionError.invalidPeer
        }

        let pairKey = Self.pairKey(currentUserId, userId)
        let requestRef = db.collection(requestsCollection).document(pairKey)

        let data: [String: Any] = [
            "fromUserId": currentUserId,
            "toUserId": userId,
            "status": ConnectionStatus.pending.rawValue,
            "createdAt": Timestamp(date: Date()),
            "pairKey": pairKey
        ]

        // Transaction + pairKey doc id prevents duplicate pending/accepted races.
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(requestRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }

                if snapshot.exists {
                    let status = snapshot.data()?["status"] as? String ?? ""
                    if status == ConnectionStatus.pending.rawValue
                        || status == ConnectionStatus.accepted.rawValue {
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreConnectionRepository",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: FirestoreConnectionError.duplicateRequest.localizedDescription]
                        )
                        return nil
                    }
                }

                transaction.setData(data, forDocument: requestRef)
                return nil
            }
        } catch {
            if (error as NSError).domain == "FirestoreConnectionRepository" {
                throw FirestoreConnectionError.duplicateRequest
            }
            let message = error.localizedDescription.lowercased()
            if message.contains("already exists") || message.contains("duplicate") {
                throw FirestoreConnectionError.duplicateRequest
            }
            throw error
        }
    }

    func fetchIncomingRequests() async throws -> [ConnectionRequest] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        // No orderBy — avoids waiting on the 3-field composite index.
        // Sort client-side instead.
        let snapshot = try await db.collection(requestsCollection)
            .whereField("toUserId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: ConnectionStatus.pending.rawValue)
            .getDocuments()

        return try snapshot.documents
            .map { try FirestoreConnectionMapper.request(from: $0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchMatchedConnections() async throws -> [ConnectionRequest] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        async let asFrom = db.collection(requestsCollection)
            .whereField("fromUserId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: ConnectionStatus.accepted.rawValue)
            .getDocuments()

        async let asTo = db.collection(requestsCollection)
            .whereField("toUserId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: ConnectionStatus.accepted.rawValue)
            .getDocuments()

        let (fromSnapshot, toSnapshot) = try await (asFrom, asTo)
        let documents = fromSnapshot.documents + toSnapshot.documents

        var seen = Set<String>()
        var requests: [ConnectionRequest] = []
        requests.reserveCapacity(documents.count)

        for document in documents {
            guard seen.insert(document.documentID).inserted else { continue }
            requests.append(try FirestoreConnectionMapper.request(from: document))
        }

        return requests.sorted { $0.createdAt > $1.createdAt }
    }

    func respond(to requestId: String, accept: Bool) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        let requestRef = db.collection(requestsCollection).document(requestId)
        let document = try await requestRef.getDocument()
        guard document.exists else {
            throw FirestoreConnectionError.requestNotFound
        }

        let data = document.data() ?? [:]
        guard data["toUserId"] as? String == currentUserId else {
            throw FirestoreConnectionError.notRecipient
        }

        let statusRaw = data["status"] as? String ?? ""
        guard statusRaw == ConnectionStatus.pending.rawValue else {
            throw FirestoreConnectionError.invalidStatusTransition
        }

        let newStatus = accept ? ConnectionStatus.accepted : ConnectionStatus.declined
        try await requestRef.updateData(["status": newStatus.rawValue])
    }

    func fetchConnection(with peerId: String) async throws -> ConnectionRequest? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        guard currentUserId != peerId else {
            throw FirestoreConnectionError.invalidPeer
        }

        let pairKey = Self.pairKey(currentUserId, peerId)
        let document = try await db.collection(requestsCollection).document(pairKey).getDocument()
        guard document.exists else { return nil }
        return try FirestoreConnectionMapper.request(from: document)
    }

    func removeConnection(with peerId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw FirestoreConnectionError.notAuthenticated
        }

        guard currentUserId != peerId else {
            throw FirestoreConnectionError.invalidPeer
        }

        let pairKey = Self.pairKey(currentUserId, peerId)
        let requestRef = db.collection(requestsCollection).document(pairKey)
        let document = try await requestRef.getDocument()
        guard document.exists else {
            throw FirestoreConnectionError.requestNotFound
        }

        let data = document.data() ?? [:]
        let fromUserId = data["fromUserId"] as? String
        let toUserId = data["toUserId"] as? String
        guard currentUserId == fromUserId || currentUserId == toUserId else {
            throw FirestoreConnectionError.notParticipant
        }

        let statusRaw = data["status"] as? String ?? ""
        guard statusRaw == ConnectionStatus.accepted.rawValue else {
            throw FirestoreConnectionError.invalidStatusTransition
        }

        try await requestRef.updateData(["status": ConnectionStatus.declined.rawValue])
    }

    // MARK: - Private

    private func connectedOrPendingPeerIds(for userId: String) async throws -> Set<String> {
        let statuses = [
            ConnectionStatus.pending.rawValue,
            ConnectionStatus.accepted.rawValue
        ]

        async let asFrom = db.collection(requestsCollection)
            .whereField("fromUserId", isEqualTo: userId)
            .whereField("status", in: statuses)
            .getDocuments()

        async let asTo = db.collection(requestsCollection)
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", in: statuses)
            .getDocuments()

        let (fromSnapshot, toSnapshot) = try await (asFrom, asTo)
        var peers = Set<String>()

        for document in fromSnapshot.documents {
            if let toUserId = document.data()["toUserId"] as? String {
                peers.insert(toUserId)
            }
        }
        for document in toSnapshot.documents {
            if let fromUserId = document.data()["fromUserId"] as? String {
                peers.insert(fromUserId)
            }
        }

        return peers
    }

    static func pairKey(_ userIdA: String, _ userIdB: String) -> String {
        [userIdA, userIdB].sorted().joined(separator: "_")
    }
}
