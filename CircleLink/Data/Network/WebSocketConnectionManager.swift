import Foundation

/// App lifecycle state without importing SwiftUI.
nonisolated enum AppLifecycleState: Sendable, Equatable {
    case foreground
    case background
}

/// Owns WebSocket connection lifecycle: foreground connect, background disconnect, token refresh.
///
/// Data flow:
/// ScenePhase (App) → handleLifecycleChange → connect/disconnect
/// Auth state (AppCoordinator) → setUserAuthenticated → connect when foreground
/// TokenProvider → fresh Firebase ID token → WebSocketClient.connect(token:)
/// WebSocketClient.observeEvents → auth_failed → force token refresh → reconnect
final class WebSocketConnectionManager: @unchecked Sendable {
    private let client: WebSocketClientProtocol
    private let tokenProvider: IDTokenProviding
    private let tokenStorage: SecureTokenStorage
    private let lock = NSLock()

    private nonisolated(unsafe) var observationTask: Task<Void, Never>?
    private nonisolated(unsafe) var reconnectTask: Task<Void, Never>?
    private nonisolated(unsafe) var connectTask: Task<Void, Never>?
    private nonisolated(unsafe) var lifecycleState: AppLifecycleState = .background
    private nonisolated(unsafe) var isUserAuthenticated = false

    nonisolated init(
        client: WebSocketClientProtocol,
        tokenProvider: IDTokenProviding,
        tokenStorage: SecureTokenStorage
    ) {
        self.client = client
        self.tokenProvider = tokenProvider
        self.tokenStorage = tokenStorage
        startObservingEvents()
    }

    deinit {
        observationTask?.cancel()
        reconnectTask?.cancel()
        connectTask?.cancel()
    }

    // MARK: - Public API (called from App layer)

    /// Updates whether a signed-in user session exists.
    nonisolated func setUserAuthenticated(_ authenticated: Bool) {
        let state = lock.withLock { () -> AppLifecycleState in
            isUserAuthenticated = authenticated
            return lifecycleState
        }

        if authenticated, state == .foreground {
            scheduleConnect(forceRefresh: false)
        } else if !authenticated {
            cancelPendingConnect()
            client.disconnect()
        }
    }

    /// Maps SwiftUI ScenePhase to connect/disconnect behaviour.
    nonisolated func handleLifecycleChange(_ state: AppLifecycleState) {
        let authenticated = lock.withLock { () -> Bool in
            lifecycleState = state
            return isUserAuthenticated
        }

        switch state {
        case .foreground:
            if authenticated {
                scheduleConnect(forceRefresh: false)
            }
        case .background:
            cancelPendingConnect()
            reconnectTask?.cancel()
            client.disconnect()
        }
    }

    /// Explicit join helper for future chat screens (Phase 5+).
    nonisolated func joinChat(_ chatId: String) {
        client.join(chatId: chatId)
    }

    /// Explicit leave helper for future chat screens (Phase 5+).
    nonisolated func leaveChat(_ chatId: String) {
        client.leave(chatId: chatId)
    }

    nonisolated var isConnected: Bool {
        client.isConnected
    }

    // MARK: - Connection

    /// Coalesces overlapping connect requests (auth + lifecycle + route changes).
    nonisolated private func scheduleConnect(forceRefresh: Bool) {
        if forceRefresh {
            connectTask?.cancel()
        } else if connectTask != nil {
            return
        }

        connectTask = Task { [weak self] in
            guard let self else { return }
            await self.performConnect(forceRefresh: forceRefresh)
            self.lock.withLock {
                self.connectTask = nil
            }
        }
    }

    nonisolated private func cancelPendingConnect() {
        connectTask?.cancel()
        lock.withLock {
            connectTask = nil
        }
    }

    nonisolated private func performConnect(forceRefresh: Bool) async {
        let shouldConnect = lock.withLock {
            isUserAuthenticated && lifecycleState == .foreground
        }

        guard shouldConnect else { return }

        if !forceRefresh, client.isConnected {
            return
        }

        do {
            var token = try await tokenProvider.fetchIDToken(forceRefresh: forceRefresh)

            if token == nil {
                token = try tokenStorage.load(for: .firebaseIDToken)
            }

            guard let token else {
                print("[WebSocketConnectionManager] no token available — skipping connect")
                return
            }

            guard !Task.isCancelled else { return }

            try await client.connect(token: token)

            guard !Task.isCancelled else { return }

            try tokenStorage.save(token: token, for: .firebaseIDToken)
        } catch is CancellationError {
            return
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }
            print("[WebSocketConnectionManager] connect failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Event observation

    nonisolated private func startObservingEvents() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.client.observeEvents() {
                guard !Task.isCancelled else { break }
                await self.handleServerEvent(event)
            }
        }
    }

    nonisolated private func handleServerEvent(_ event: WebSocketEvent) async {
        guard case let .error(code) = event else { return }

        switch code {
        case "auth_failed", "auth_timeout", "auth_required":
            reconnectTask?.cancel()
            reconnectTask = Task { [weak self] in
                guard let self else { return }

                self.client.disconnect()
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }

                self.scheduleConnect(forceRefresh: true)
            }
        default:
            break
        }
    }
}
