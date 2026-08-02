import Foundation

enum FirestoreChatError: LocalizedError {
    case notAuthenticated
    case missingTextAndImage
    case uploadFailed
    case invalidPeer
    case chatNotFound
    case notCommunityMember
    case emptyParticipants

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use chat."
        case .missingTextAndImage:
            return "Message must include text or an image."
        case .uploadFailed:
            return "Failed to upload image."
        case .invalidPeer:
            return "Cannot create a chat with yourself."
        case .chatNotFound:
            return "Chat could not be found."
        case .notCommunityMember:
            return "Only community members can open this group chat."
        case .emptyParticipants:
            return "Group chat needs at least one member."
        }
    }
}
