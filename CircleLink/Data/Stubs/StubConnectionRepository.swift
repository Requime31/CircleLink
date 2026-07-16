import Foundation

final class StubConnectionRepository: ConnectionRepository, @unchecked Sendable {
    func fetchCandidates(communityId: String) async throws -> [User] { [] }

    func sendConnect(to userId: String, in communityId: String) async throws {}

    func fetchIncomingRequests() async throws -> [ConnectionRequest] { [] }

    func fetchMatchedConnections() async throws -> [ConnectionRequest] { [] }

    func respond(to requestId: String, accept: Bool) async throws {}
}
