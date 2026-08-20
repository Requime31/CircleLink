import Foundation

/// Push destination for community detail. `name` is the nav title from frame one,
/// so the large "Communities" title does not morph into the placeholder "Community".
struct CommunityDetailRoute: Hashable {
    let id: String
    let name: String
}
