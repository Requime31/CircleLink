import Foundation

final class StubWebSocketClient: WebSocketClientProtocol, @unchecked Sendable {
    private nonisolated(unsafe) var _isConnected = false

    nonisolated var isConnected: Bool { _isConnected }

    nonisolated func connect(token: String) async throws {
        _isConnected = true
    }

    nonisolated func disconnect() {
        _isConnected = false
    }

    nonisolated func join(chatId: String) {}

    nonisolated func leave(chatId: String) {}

    nonisolated func send(event: WebSocketEvent) {}

    nonisolated func observeEvents() -> AsyncStream<WebSocketEvent> {
        AsyncStream { _ in }
    }
}
