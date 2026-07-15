import Foundation

protocol WebSocketClientProtocol: Sendable {
    nonisolated func connect(token: String) async throws
    nonisolated func disconnect()
    nonisolated func join(chatId: String)
    nonisolated func leave(chatId: String)
    nonisolated func send(event: WebSocketEvent)
    nonisolated func observeEvents() -> AsyncStream<WebSocketEvent>
    nonisolated var isConnected: Bool { get }
}
