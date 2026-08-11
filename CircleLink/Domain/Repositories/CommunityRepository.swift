import Foundation

protocol CommunityRepository: Sendable {
    func fetchCommunities() async throws -> [Community]
    func fetchMembers(communityId: String) async throws -> [User]
    func join(communityId: String) async throws
    func leave(communityId: String) async throws

    /// Creates a community and joins the creator as admin (`memberCount == 1`).
    func createCommunity(
        name: String,
        description: String,
        interestTag: String
    ) async throws -> Community

    /// How many communities the signed-in user has joined (Circles count on Profile).
    func fetchJoinedCommunityCount() async throws -> Int
}
