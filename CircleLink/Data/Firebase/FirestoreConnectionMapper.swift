import FirebaseFirestore
import Foundation

enum FirestoreConnectionMapper {
    enum MapperError: LocalizedError {
        case missingRequiredField(String)

        var errorDescription: String? {
            switch self {
            case let .missingRequiredField(field):
                return "Connection request is missing \(field)."
            }
        }
    }

    static func request(from document: DocumentSnapshot) throws -> ConnectionRequest {
        let data = document.data() ?? [:]

        guard let fromUserId = data["fromUserId"] as? String, !fromUserId.isEmpty else {
            throw MapperError.missingRequiredField("fromUserId")
        }
        guard let toUserId = data["toUserId"] as? String, !toUserId.isEmpty else {
            throw MapperError.missingRequiredField("toUserId")
        }

        let rawCommunityId = data["communityId"] as? String
        let communityId = rawCommunityId.flatMap { $0.isEmpty ? nil : $0 }

        let statusRaw = data["status"] as? String ?? ConnectionStatus.pending.rawValue

        return ConnectionRequest(
            id: document.documentID,
            fromUserId: fromUserId,
            toUserId: toUserId,
            communityId: communityId,
            status: ConnectionStatus(rawValue: statusRaw) ?? .pending,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
}
