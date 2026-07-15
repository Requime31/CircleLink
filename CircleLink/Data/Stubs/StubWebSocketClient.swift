import Foundation

final class StubWebSocketClient: WebSocketClientProtocol, @unchecked Sendable {
    private(set) var isConnected = false

    func connect(token: String) async throws {
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    func join(chatId: String) {}

    func leave(chatId: String) {}

    func send(event: WebSocketEvent) {}

    func observeEvents() -> AsyncStream<WebSocketEvent> {
        AsyncStream { _ in }
    }
}
