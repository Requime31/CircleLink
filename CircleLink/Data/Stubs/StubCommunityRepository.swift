import Foundation

final class StubCommunityRepository: CommunityRepository, @unchecked Sendable {
    private var communities: [Community] = []

    func fetchCommunities() async throws -> [Community] { communities }

    func fetchMembers(communityId: String) async throws -> [User] { [] }

    func join(communityId: String) async throws {}

    func leave(communityId: String) async throws {}

    func updateCoverURL(communityId: String, url: URL?) async throws {
        guard let index = communities.firstIndex(where: { $0.id == communityId }) else { return }
        let community = communities[index]
        communities[index] = Community(
            id: community.id, name: community.name, description: community.description,
            interestTag: community.interestTag, memberCount: community.memberCount,
            coverImageURL: url, createdAt: community.createdAt, creatorId: community.creatorId
        )
    }

    func createCommunity(
        name: String,
        description: String,
        interestTag: String
    ) async throws -> Community {
        let community = Community(
            id: UUID().uuidString,
            name: name,
            description: description,
            interestTag: interestTag,
            memberCount: 1
        )
        communities.append(community)
        return community
    }

    func fetchJoinedCommunityCount() async throws -> Int {
        // Stub has no membership graph — treat created list as joined for previews.
        communities.count
    }

    func fetchCommunities(forUserId userId: String) async throws -> [Community] {
        _ = userId
        return communities
    }
}
