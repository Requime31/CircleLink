import FirebaseAuth
import Foundation
import os

enum FirebaseAuthError: LocalizedError {
    case notConfigured
    case missingUser

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase is not configured. Check GoogleService-Info.plist and restart the app."
        case .missingUser:
            return "No authenticated Firebase user found."
        }
    }
}

/// Serializes auth side effects across suspension points (Firebase user, token, cache).
private actor AuthOperationGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func run<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}

final class FirebaseAuthRepository: AuthRepository {
    private struct CacheState: Sendable {
        var user: User?
        var generation: UInt64 = 0
    }

    private let tokenStorage: SecureTokenStorage
    private let userRepository: UserRepository
    private let appleSignInPresenter: AppleSignInPresenter
    private let operationGate = AuthOperationGate()

    /// AuthRepository is Sendable, so every cache access must be safe from any executor.
    /// The generation also prevents an older async restore/sign-in from winning after sign-out.
    private let cache = OSAllocatedUnfairLock(initialState: CacheState())

    var currentUser: User? {
        if let cachedUser = cache.withLock({ $0.user }) {
            return cachedUser
        }
        guard FirebaseBootstrap.isConfigured,
              let firebaseUser = Auth.auth().currentUser else {
            return nil
        }
        return User(
            id: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? "",
            avatarURL: nil,
            avatarBase64: nil,
            interests: [],
            ageConfirmedAt: nil
        )
    }

    init(
        tokenStorage: SecureTokenStorage,
        userRepository: UserRepository,
        appleSignInPresenter: AppleSignInPresenter
    ) {
        self.tokenStorage = tokenStorage
        self.userRepository = userRepository
        self.appleSignInPresenter = appleSignInPresenter
    }

    func signInWithApple() async throws -> User {
        try await operationGate.run { [self] in
            try await performSignInWithApple()
        }
    }

    private func performSignInWithApple() async throws -> User {
        try ensureConfigured()
        let cacheGeneration = beginCacheOperation()

        let appleResult = try await appleSignInPresenter.signIn()

        let credential = OAuthProvider.appleCredential(
            withIDToken: appleResult.idToken,
            rawNonce: appleResult.nonce,
            fullName: appleResult.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        return try await completeSignIn(for: authResult.user, cacheGeneration: cacheGeneration)
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        try await operationGate.run { [self] in
            try await performSignInWithEmail(email: email, password: password)
        }
    }

    private func performSignInWithEmail(email: String, password: String) async throws -> User {
        try ensureConfigured()
        let cacheGeneration = beginCacheOperation()

        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            return try await completeSignIn(for: authResult.user, cacheGeneration: cacheGeneration)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signUpWithEmail(email: String, password: String) async throws -> User {
        try await operationGate.run { [self] in
            try await performSignUpWithEmail(email: email, password: password)
        }
    }

    private func performSignUpWithEmail(email: String, password: String) async throws -> User {
        try ensureConfigured()
        let cacheGeneration = beginCacheOperation()

        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            return try await completeSignIn(for: authResult.user, cacheGeneration: cacheGeneration)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signOut() async throws {
        try await operationGate.run { [self] in
            try performSignOut()
        }
    }

    private func performSignOut() throws {
        guard FirebaseBootstrap.isConfigured else { return }
        try Auth.auth().signOut()
        invalidateCache()
        try tokenStorage.delete(for: .firebaseIDToken)
    }

    func restoreSessionProfile() async throws -> User? {
        try await operationGate.run { [self] in
            try await performRestoreSessionProfile()
        }
    }

    private func performRestoreSessionProfile() async throws -> User? {
        try ensureConfigured()
        let cacheGeneration = beginCacheOperation()

        guard let userId = Auth.auth().currentUser?.uid else {
            updateCachedUser(nil, generation: cacheGeneration)
            return nil
        }

        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            try tokenStorage.save(token: token, for: .firebaseIDToken)
        }

        let profile = try await userRepository.fetchProfile(userId: userId)
        guard Auth.auth().currentUser?.uid == userId else { return nil }
        guard updateCachedUser(profile, generation: cacheGeneration) else { return nil }
        return profile
    }

    private func completeSignIn(
        for user: FirebaseAuth.User,
        cacheGeneration: UInt64
    ) async throws -> User {
        try await persistToken(for: user)
        let profile = try await userRepository.fetchProfile(userId: user.uid)
        guard Auth.auth().currentUser?.uid == user.uid,
              updateCachedUser(profile, generation: cacheGeneration) else {
            throw CancellationError()
        }
        return profile
    }

    private func beginCacheOperation() -> UInt64 {
        cache.withLock {
            $0.generation &+= 1
            return $0.generation
        }
    }

    @discardableResult
    private func updateCachedUser(_ user: User?, generation: UInt64) -> Bool {
        cache.withLock {
            guard $0.generation == generation else { return false }
            $0.user = user
            return true
        }
    }

    private func invalidateCache() {
        cache.withLock {
            $0.generation &+= 1
            $0.user = nil
        }
    }

    private func persistToken(for user: FirebaseAuth.User) async throws {
        let token = try await user.getIDToken()
        try tokenStorage.save(token: token, for: .firebaseIDToken)
    }

    private func ensureConfigured() throws {
        guard FirebaseBootstrap.isConfigured else {
            throw FirebaseAuthError.notConfigured
        }
    }

    private func mapAuthError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }

        switch code {
        case .userNotFound, .wrongPassword, .invalidCredential:
            return AuthFlowError.invalidCredentials
        case .emailAlreadyInUse:
            return AuthFlowError.emailAlreadyInUse
        case .weakPassword:
            return AuthFlowError.weakPassword
        case .invalidEmail:
            return AuthFlowError.invalidEmail
        default:
            return error
        }
    }
}

enum AuthFlowError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Use Create Account if you are new."
        case .emailAlreadyInUse:
            return "This email is already registered. Try Sign In instead."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .invalidEmail:
            return "Enter a valid email address."
        }
    }
}
