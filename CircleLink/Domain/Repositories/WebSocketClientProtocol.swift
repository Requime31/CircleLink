import Foundation

protocol WebSocketClientProtocol: Sendable {
    func connect(token: String) async throws
    func disconnect()
    func join(chatId: String)
    func leave(chatId: String)
    func send(event: WebSocketEvent)
    func observeEvents() -> AsyncStream<WebSocketEvent>
    var isConnected: Bool { get }
}
