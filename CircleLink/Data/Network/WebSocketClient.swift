import Foundation

enum WebSocketClientError: LocalizedError {
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
final class WebSocketClient: WebSocketClientProtocol, @unchecked Sendable {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var eventContinuation: AsyncStream<WebSocketEvent>.Continuation?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var authToken: String?
    private var joinedChatIds: Set<String> = []
    private var intentionalDisconnect = false
    private var reconnectEnabled = false
    private var backoffAttempt = 0
    private var _isConnected = false

    init(url: URL = WebSocketConfiguration.serverURL) {
        self.url = url
    }

    deinit {
        tearDown(cancelReconnect: true, finishStream: true)
    }

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    // MARK: - WebSocketClientProtocol

    func connect(token: String) async throws {
        lock.lock()
        intentionalDisconnect = false
        reconnectEnabled = true
        authToken = token
        backoffAttempt = 0
        lock.unlock()

        reconnectTask?.cancel()
        try await establishConnection(sendAuth: true)
    }

    func disconnect() {
        lock.lock()
        intentionalDisconnect = true
        reconnectEnabled = false
        lock.unlock()

        tearDown(cancelReconnect: true, finishStream: false)
    }

    func join(chatId: String) {
        lock.lock()
        joinedChatIds.insert(chatId)
        lock.unlock()

        send(event: .join(chatId: chatId))
    }

    func leave(chatId: String) {
        lock.lock()
        joinedChatIds.remove(chatId)
        lock.unlock()

        send(event: .leave(chatId: chatId))
    }

    func send(event: WebSocketEvent) {
        guard let payload = encode(event) else { return }

        lock.lock()
        let task = webSocketTask
        let connected = _isConnected
        lock.unlock()

        guard connected, let task else { return }

        task.send(.string(payload)) { error in
            if let error {
                print("[WebSocketClient] send failed: \(error.localizedDescription)")
            }
        }
    }

    func observeEvents() -> AsyncStream<WebSocketEvent> {
        AsyncStream { continuation in
            lock.lock()
            eventContinuation = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.eventContinuation = nil
                self?.lock.unlock()
            }
        }
    }

    // MARK: - Connection

    private func establishConnection(sendAuth: Bool) async throws {
        tearDownSocket()

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()

        lock.lock()
        urlSession = session
        webSocketTask = task
        lock.unlock()

        if sendAuth {
            let token: String
            lock.lock()
            guard let authToken else {
                lock.unlock()
                throw WebSocketClientError.missingToken
            }
            token = authToken
            lock.unlock()

            try await sendAndWait(.auth(token: token), on: task)
        }

        lock.lock()
        _isConnected = true
        backoffAttempt = 0
        let roomsToRejoin = joinedChatIds
        lock.unlock()

        startReceiveLoop()

        for chatId in roomsToRejoin where sendAuth {
            send(event: .join(chatId: chatId))
        }
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            await self?.receiveMessages()
        }
    }

    private func receiveMessages() async {
        while !Task.isCancelled {
            let task: URLSessionWebSocketTask?
            lock.lock()
            task = webSocketTask
            lock.unlock()

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
                handleUnexpectedDisconnect(error: error)
                break
            }
        }
    }

    private func handleIncoming(_ text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? decoder.decode(WebSocketEvent.self, from: data) else {
            return
        }

        lock.lock()
        let continuation = eventContinuation
        lock.unlock()

        continuation?.yield(event)

        if case let .error(code) = event, code == "auth_failed" {
            lock.lock()
            _isConnected = false
            lock.unlock()
        }
    }

    private func handleUnexpectedDisconnect(error: Error) {
        print("[WebSocketClient] disconnected: \(error.localizedDescription)")

        lock.lock()
        _isConnected = false
        let shouldReconnect = reconnectEnabled && !intentionalDisconnect
        lock.unlock()

        tearDownSocket()

        if shouldReconnect {
            scheduleReconnect()
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        reconnectTask?.cancel()

        lock.lock()
        let attempt = backoffAttempt
        backoffAttempt += 1
        lock.unlock()

        let delay = Self.backoffDelay(forAttempt: attempt)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }

            let shouldProceed: Bool
            self.lock.lock()
            shouldProceed = self.reconnectEnabled && !self.intentionalDisconnect
            self.lock.unlock()

            guard shouldProceed else { return }

            do {
                try await self.establishConnection(sendAuth: true)
            } catch {
                print("[WebSocketClient] reconnect failed: \(error.localizedDescription)")
                self.handleUnexpectedDisconnect(error: error)
            }
        }
    }

    private static func backoffDelay(forAttempt attempt: Int) -> Double {
        let cappedAttempt = min(attempt, 5)
        let base = min(30.0, pow(2.0, Double(cappedAttempt)))
        let jitter = Double.random(in: 0...1)
        return base + jitter
    }

    // MARK: - Teardown

    private func tearDown(cancelReconnect: Bool, finishStream: Bool) {
        if cancelReconnect {
            reconnectTask?.cancel()
            reconnectTask = nil
        }

        receiveTask?.cancel()
        receiveTask = nil

        tearDownSocket()

        lock.lock()
        _isConnected = false
        if finishStream {
            eventContinuation?.finish()
            eventContinuation = nil
        }
        lock.unlock()
    }

    private func tearDownSocket() {
        lock.lock()
        let task = webSocketTask
        let session = urlSession
        webSocketTask = nil
        urlSession = nil
        lock.unlock()

        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }

    // MARK: - Encoding

    private func encode(_ event: WebSocketEvent) -> String? {
        guard let data = try? encoder.encode(event),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func sendAndWait(_ event: WebSocketEvent, on task: URLSessionWebSocketTask) async throws {
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
}
