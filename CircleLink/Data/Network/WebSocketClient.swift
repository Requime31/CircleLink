import Foundation

nonisolated enum WebSocketClientError: LocalizedError {
    case missingToken
    case notConnected
    case encodingFailed
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Missing authentication token for WebSocket connection."
        case .notConnected:
            return "WebSocket is not connected."
        case .encodingFailed:
            return "Failed to encode WebSocket event."
        case let .connectionFailed(reason):
            return "WebSocket connection failed: \(reason)"
        }
    }
}

/// URLSession-based WebSocket transport with exponential-backoff reconnect.
/// Opts out of default `@MainActor` isolation — all socket I/O stays off the main thread.
final class WebSocketClient: WebSocketClientProtocol, @unchecked Sendable {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private nonisolated(unsafe) var urlSession: URLSession?
    private nonisolated(unsafe) var webSocketTask: URLSessionWebSocketTask?
    private nonisolated(unsafe) var eventContinuations: [UUID: AsyncStream<WebSocketEvent>.Continuation] = [:]
    private nonisolated(unsafe) var receiveTask: Task<Void, Never>?
    private nonisolated(unsafe) var reconnectTask: Task<Void, Never>?

    private nonisolated(unsafe) var authToken: String?
    private nonisolated(unsafe) var joinedChatIds: Set<String> = []
    private nonisolated(unsafe) var intentionalDisconnect = false
    private nonisolated(unsafe) var reconnectEnabled = false
    private nonisolated(unsafe) var backoffAttempt = 0
    private nonisolated(unsafe) var _isConnected = false

    nonisolated init(url: URL) {
        self.url = url
    }

    deinit {
        tearDown(cancelReconnect: true, finishStream: true)
    }

    nonisolated var isConnected: Bool {
        lock.withLock { _isConnected }
    }

    // MARK: - WebSocketClientProtocol

    nonisolated func connect(token: String) async throws {
        lock.withLock {
            intentionalDisconnect = false
            reconnectEnabled = true
            authToken = token
            backoffAttempt = 0
        }

        reconnectTask?.cancel()
        try await establishConnection(sendAuth: true)
    }

    nonisolated func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil

        lock.withLock {
            intentionalDisconnect = true
            reconnectEnabled = false
        }

        tearDown(cancelReconnect: true, finishStream: false)
    }

    nonisolated func join(chatId: String) {
        lock.withLock {
            _ = joinedChatIds.insert(chatId)
        }

        send(event: .join(chatId: chatId))
    }

    nonisolated func leave(chatId: String) {
        lock.withLock {
            _ = joinedChatIds.remove(chatId)
        }

        send(event: .leave(chatId: chatId))
    }

    nonisolated func send(event: WebSocketEvent) {
        guard let payload = encode(event) else { return }

        let (task, connected) = lock.withLock {
            (webSocketTask, _isConnected)
        }

        guard connected, let task else { return }

        task.send(.string(payload)) { error in
            if let error {
                print("[WebSocketClient] send failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func observeEvents() -> AsyncStream<WebSocketEvent> {
        let subscriberID = UUID()

        return AsyncStream { continuation in
            lock.withLock {
                eventContinuations[subscriberID] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock {
                    self?.eventContinuations.removeValue(forKey: subscriberID)
                }
            }
        }
    }

    // MARK: - Connection

    nonisolated private func establishConnection(sendAuth: Bool) async throws {
        tearDownSocket()

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()

        lock.withLock {
            urlSession = session
            webSocketTask = task
        }

        if sendAuth {
            let token = lock.withLock { () -> String in
                guard let authToken else {
                    return ""
                }
                return authToken
            }

            guard !token.isEmpty else {
                throw WebSocketClientError.missingToken
            }

            try await sendAndWait(.auth(token: token), on: task)
        }

        let roomsToRejoin = lock.withLock { () -> Set<String> in
            _isConnected = true
            backoffAttempt = 0
            return joinedChatIds
        }

        startReceiveLoop()

        if sendAuth {
            for chatId in roomsToRejoin {
                send(event: .join(chatId: chatId))
            }
        }
    }

    nonisolated private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            await self?.receiveMessages()
        }
    }

    nonisolated private func receiveMessages() async {
        while !Task.isCancelled {
            let task = lock.withLock { webSocketTask }
            guard let task else { break }

            do {
                let message = try await task.receive()
                guard !Task.isCancelled else { break }

                switch message {
                case let .string(text):
                    handleIncoming(text)
                case let .data(data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleIncoming(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                guard !Task.isCancelled else { break }

                if self.isIntentionalDisconnect() {
                    break
                }

                if Self.isBenignDisconnectError(error) {
                    break
                }

                handleUnexpectedDisconnect(error: error)
                break
            }
        }
    }

    nonisolated private func handleIncoming(_ text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? decoder.decode(WebSocketEvent.self, from: data) else {
            return
        }

        let continuations = lock.withLock { Array(eventContinuations.values) }
        for continuation in continuations {
            continuation.yield(event)
        }

        if case let .error(code) = event, code == "auth_failed" {
            lock.withLock {
                _isConnected = false
            }
        }
    }

    nonisolated private func handleUnexpectedDisconnect(error: Error) {
        guard !isIntentionalDisconnect() else { return }

        print("[WebSocketClient] disconnected: \(error.localizedDescription)")

        let shouldReconnect = lock.withLock { () -> Bool in
            _isConnected = false
            return reconnectEnabled && !intentionalDisconnect
        }

        tearDownSocket()

        if shouldReconnect {
            scheduleReconnect()
        }
    }

    // MARK: - Reconnect

    nonisolated private func scheduleReconnect() {
        reconnectTask?.cancel()

        let attempt = lock.withLock { () -> Int in
            let current = backoffAttempt
            backoffAttempt += 1
            return current
        }

        let delay = Self.backoffDelay(forAttempt: attempt)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }

            let shouldProceed = self.lock.withLock {
                self.reconnectEnabled && !self.intentionalDisconnect
            }

            guard shouldProceed else { return }

            do {
                try await self.establishConnection(sendAuth: true)
            } catch {
                print("[WebSocketClient] reconnect failed: \(error.localizedDescription)")
                self.handleUnexpectedDisconnect(error: error)
            }
        }
    }

    nonisolated private static func backoffDelay(forAttempt attempt: Int) -> Double {
        let cappedAttempt = min(attempt, 5)
        let base = min(30.0, pow(2.0, Double(cappedAttempt)))
        let jitter = Double.random(in: 0...1)
        return base + jitter
    }

    // MARK: - Teardown

    nonisolated private func tearDown(cancelReconnect: Bool, finishStream: Bool) {
        if cancelReconnect {
            reconnectTask?.cancel()
            reconnectTask = nil
        }

        receiveTask?.cancel()
        receiveTask = nil

        tearDownSocket()

        lock.withLock {
            _isConnected = false
            if finishStream {
                for continuation in eventContinuations.values {
                    continuation.finish()
                }
                eventContinuations.removeAll()
            }
        }
    }

    nonisolated private func tearDownSocket() {
        let (task, session) = lock.withLock {
            let task = webSocketTask
            let session = urlSession
            webSocketTask = nil
            urlSession = nil
            return (task, session)
        }

        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }

    // MARK: - Encoding

    nonisolated private func encode(_ event: WebSocketEvent) -> String? {
        guard let data = try? encoder.encode(event),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    nonisolated private func sendAndWait(_ event: WebSocketEvent, on task: URLSessionWebSocketTask) async throws {
        guard let payload = encode(event) else {
            throw WebSocketClientError.encodingFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.string(payload)) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    nonisolated private func isIntentionalDisconnect() -> Bool {
        lock.withLock { intentionalDisconnect }
    }

    /// Errors expected when we cancel the socket during lifecycle disconnect.
    nonisolated private static func isBenignDisconnectError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain, nsError.code == 57 {
            return true
        }

        if nsError.localizedDescription.contains("Socket is not connected") {
            return true
        }

        return false
    }
}
