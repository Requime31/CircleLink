import Foundation

final class StubConnectionRepository: ConnectionRepository, @unchecked Sendable {
    var connection: ConnectionRequest?

    func fetchCandidates() async throws -> [User] { [] }

    func sendConnect(to userId: String) async throws {}

    func fetchIncomingRequests() async throws -> [ConnectionRequest] { [] }

    func fetchOutgoingPendingRequests() async throws -> [ConnectionRequest] { [] }

    func fetchMatchedConnections() async throws -> [ConnectionRequest] { [] }

    func respond(to requestId: String, accept: Bool) async throws {}

    func cancelOutgoingRequest(requestId: String) async throws {
        guard var existing = connection, existing.id == requestId,
              existing.status == .pending else { return }
        existing.status = .declined
        connection = existing
    }

    func fetchConnection(with peerId: String) async throws -> ConnectionRequest? {
        connection
    }

    func removeConnection(with peerId: String) async throws {
        guard var existing = connection, existing.status == .accepted else { return }
        existing.status = .declined
        connection = existing
    }
}
