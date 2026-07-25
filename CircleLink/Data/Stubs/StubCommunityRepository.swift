import Foundation

final class StubCommunityRepository: CommunityRepository, @unchecked Sendable {
    private var communities: [Community] = []

    func fetchCommunities() async throws -> [Community] { communities }

    func fetchMembers(communityId: String) async throws -> [User] { [] }

    func join(communityId: String) async throws {}

    func leave(communityId: String) async throws {}

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
}
