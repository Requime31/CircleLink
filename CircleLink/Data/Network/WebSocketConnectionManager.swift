import Foundation

/// App lifecycle state without importing SwiftUI.
enum AppLifecycleState: Sendable {
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

    private var observationTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var lifecycleState: AppLifecycleState = .background
    private var isUserAuthenticated = false

    init(
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
    }

    // MARK: - Public API (called from App layer)

    /// Updates whether a signed-in user session exists.
    func setUserAuthenticated(_ authenticated: Bool) {
        lock.lock()
        isUserAuthenticated = authenticated
        let state = lifecycleState
        lock.unlock()

        if authenticated, state == .foreground {
            Task { await self.connect(forceRefresh: false) }
        } else if !authenticated {
            client.disconnect()
        }
    }

    /// Maps SwiftUI ScenePhase to connect/disconnect behaviour.
    func handleLifecycleChange(_ state: AppLifecycleState) {
        lock.lock()
        lifecycleState = state
        let authenticated = isUserAuthenticated
        lock.unlock()

        switch state {
        case .foreground:
            if authenticated {
                Task { await self.connect(forceRefresh: false) }
            }
        case .background:
            reconnectTask?.cancel()
            client.disconnect()
        }
    }

    /// Explicit join helper for future chat screens (Phase 5+).
    func joinChat(_ chatId: String) {
        client.join(chatId: chatId)
    }

    /// Explicit leave helper for future chat screens (Phase 5+).
    func leaveChat(_ chatId: String) {
        client.leave(chatId: chatId)
    }

    var isConnected: Bool {
        client.isConnected
    }

    // MARK: - Connection

    private func connect(forceRefresh: Bool) async {
        lock.lock()
        let shouldConnect = isUserAuthenticated && lifecycleState == .foreground
        lock.unlock()

        guard shouldConnect else { return }

        do {
            var token = try await tokenProvider.fetchIDToken(forceRefresh: forceRefresh)

            if token == nil {
                token = try tokenStorage.load(for: .firebaseIDToken)
            }

            guard let token else {
                print("[WebSocketConnectionManager] no token available — skipping connect")
                return
            }

            try await client.connect(token: token)
            try tokenStorage.save(token: token, for: .firebaseIDToken)
        } catch {
            print("[WebSocketConnectionManager] connect failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Event observation

    private func startObservingEvents() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }

            for await event in self.client.observeEvents() {
                guard !Task.isCancelled else { break }
                await self.handleServerEvent(event)
            }
        }
    }

    private func handleServerEvent(_ event: WebSocketEvent) async {
        guard case let .error(code) = event else { return }

        switch code {
        case "auth_failed", "auth_timeout", "auth_required":
            reconnectTask?.cancel()
            reconnectTask = Task { [weak self] in
                guard let self else { return }

                self.client.disconnect()
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }

                await self.connect(forceRefresh: true)
            }
        default:
            break
        }
    }
}
