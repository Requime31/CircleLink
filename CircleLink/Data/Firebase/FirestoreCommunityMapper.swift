import FirebaseFirestore
import Foundation

enum FirestoreCommunityMapper {
    static func community(from document: DocumentSnapshot) throws -> Community {
        let data = document.data() ?? [:]
        guard let name = data["name"] as? String,
              let description = data["description"] as? String,
              let interestTag = data["interestTag"] as? String else {
            throw FirestoreCommunityError.invalidData
        }

        return Community(
            id: document.documentID,
            name: name,
            description: description,
            interestTag: interestTag,
            memberCount: data["memberCount"] as? Int ?? 0
        )
    }

    static func member(from document: DocumentSnapshot) throws -> CommunityMember {
        let data = document.data() ?? [:]
        let roleRaw = data["role"] as? String ?? MemberRole.member.rawValue

        return CommunityMember(
            userId: document.documentID,
            joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date(),
            role: MemberRole(rawValue: roleRaw) ?? .member
        )
    }

    static func memberData(role: MemberRole = .member) -> [String: Any] {
        [
            "joinedAt": Timestamp(date: Date()),
            "role": role.rawValue
        ]
    }
}
