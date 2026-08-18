import FirebaseFirestore
import Foundation

enum FirestoreCommunityPostMapper {
    static let maxTextLength = 2_000

    static func post(from document: DocumentSnapshot, communityId: String) throws -> CommunityPost {
        let data = document.data() ?? [:]
        guard let authorId = data["authorId"] as? String else { throw FirestoreProfilePostError.invalidData }
        let text = (data["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL = (data["imageURL"] as? String).flatMap(URL.init(string:))
        guard text?.isEmpty == false || imageURL != nil else { throw FirestoreProfilePostError.invalidData }
        return CommunityPost(
            id: document.documentID, communityId: communityId, authorId: authorId,
            text: text?.isEmpty == false ? text : nil, imageURL: imageURL,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    static func data(authorId: String, text: String?, imageURL: URL?, createdAt: Date) -> [String: Any] {
        var result: [String: Any] = ["authorId": authorId, "createdAt": Timestamp(date: createdAt)]
        if let text, !text.isEmpty { result["text"] = text }
        if let imageURL { result["imageURL"] = imageURL.absoluteString }
        return result
    }
}
