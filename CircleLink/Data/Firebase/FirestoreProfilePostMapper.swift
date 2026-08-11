import FirebaseFirestore
import Foundation

enum FirestoreProfilePostMapper {
    static let maxTextLength = 2_000

    static func post(from document: DocumentSnapshot, authorIdFallback: String) throws -> ProfilePost {
        guard let data = document.data() else {
            throw FirestoreProfilePostError.invalidData
        }

        let rawAuthorId = (data["authorId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAuthorId: String
        if let rawAuthorId, !rawAuthorId.isEmpty {
            resolvedAuthorId = rawAuthorId
        } else if !authorIdFallback.isEmpty {
            resolvedAuthorId = authorIdFallback
        } else {
            throw FirestoreProfilePostError.invalidData
        }

        let text = (data["text"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = (text?.isEmpty == false) ? text : nil

        let imageURL = (data["imageURL"] as? String).flatMap(URL.init(string:))

        guard normalizedText != nil || imageURL != nil else {
            throw FirestoreProfilePostError.invalidData
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return ProfilePost(
            id: document.documentID,
            authorId: resolvedAuthorId,
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
