import Foundation

/// Every push destination owned by the Communities tab's single navigation stack.
enum CommunitiesRoute: Hashable {
    case allCommunities(sortOrder: CommunitySortOrder)
    case communityDetail(id: String, name: String)
}

/// Pure path mutation policy so repeated UI events cannot stack the same destination.
enum CommunitiesNavigationPathPolicy {
    static func appending(
        _ route: CommunitiesRoute,
        to path: [CommunitiesRoute]
    ) -> [CommunitiesRoute] {
        guard !route.hasSameDestination(as: path.last) else { return path }
        return path + [route]
    }
}

private extension CommunitiesRoute {
    func hasSameDestination(as other: CommunitiesRoute?) -> Bool {
        switch (self, other) {
        case (.allCommunities, .allCommunities):
            return true
        case let (.communityDetail(id, _), .communityDetail(otherID, _)):
            return id == otherID
        default:
            return false
        }
    }
}
