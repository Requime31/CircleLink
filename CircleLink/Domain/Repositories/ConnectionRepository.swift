import Foundation

protocol ConnectionRepository: Sendable {
    /// All discoverable users except self + pending/accepted connections.
    func fetchCandidates() async throws -> [User]
    func sendConnect(to userId: String) async throws
    func fetchIncomingRequests() async throws -> [ConnectionRequest]
    /// Requests sent by the current user that are still pending, newest first.
    func fetchOutgoingPendingRequests() async throws -> [ConnectionRequest]
    func fetchMatchedConnections() async throws -> [ConnectionRequest]
    func respond(to requestId: String, accept: Bool) async throws
    /// Withdraws a pending request previously sent by the current user.
    func cancelOutgoingRequest(requestId: String) async throws

    /// Pair relationship with a peer (`nil` if no request doc exists).
    func fetchConnection(with peerId: String) async throws -> ConnectionRequest?

    /// Unmatch only: `accepted` → `declined`. Does not delete chat history.
    func removeConnection(with peerId: String) async throws
}
