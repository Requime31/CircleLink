import Foundation

enum ConnectDestination: Hashable {
    case likedYou
    case matches
}

struct PresentedPeer: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}

struct ModerationTarget: Identifiable, Equatable {
    let userId: String
    let displayName: String

    var id: String { userId }
}
