import FirebaseFirestore
import Foundation

enum FirestoreCommunityPostMapper {
    static let maxTextLength = 2_000

    static func post(from document: DocumentSnapshot, communityId: String) throws -> CommunityPost {
        guard let data = document.data() else {
            throw FirestoreCommunityPostError.invalidData
        }

        guard let authorId = data["authorId"] as? String, !authorId.isEmpty else {
            throw FirestoreCommunityPostError.invalidData
        }

        let text = (data["text"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = (text?.isEmpty == false) ? text : nil

        let imageURL = (data["imageURL"] as? String).flatMap(URL.init(string:))

        guard normalizedText != nil || imageURL != nil else {
            throw FirestoreCommunityPostError.invalidData
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return CommunityPost(
            id: document.documentID,
            communityId: communityId,
            authorId: authorId,
            text: normalizedText,
            imageURL: imageURL,
            createdAt: createdAt
        )
    }

    static func postData(
        authorId: String,
        text: String?,
        imageURL: URL?,
        createdAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "authorId": authorId,
            "createdAt": Timestamp(date: createdAt)
        ]

        if let text, !text.isEmpty {
            data["text"] = text
        }

        if let imageURL {
            data["imageURL"] = imageURL.absoluteString
        }

        return data
    }
}
