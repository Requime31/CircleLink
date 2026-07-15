import Foundation

protocol CommunityRepository: Sendable {
    func fetchCommunities() async throws -> [Community]
    func fetchMembers(communityId: String) async throws -> [User]
    func join(communityId: String) async throws
    func leave(communityId: String) async throws
}
