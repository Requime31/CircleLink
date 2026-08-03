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

final class FirebaseAuthRepository: AuthRepository {
    private let tokenStorage: SecureTokenStorage
    private let userRepository: UserRepository
    private let appleSignInPresenter: AppleSignInPresenter

    /// AuthRepository is Sendable, so every cache access must be safe from any executor.
    private let cachedUser = OSAllocatedUnfairLock<User?>(initialState: nil)

    var currentUser: User? {
        if let cachedUser = cachedUser.withLock({ $0 }) {
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
        try ensureConfigured()

        let appleResult = try await appleSignInPresenter.signIn()

        let credential = OAuthProvider.appleCredential(
            withIDToken: appleResult.idToken,
            rawNonce: appleResult.nonce,
            fullName: appleResult.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        return try await completeSignIn(for: authResult.user)
    }

    func signInWithEmail(email: String, password: String) async throws -> User {
        try ensureConfigured()

        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            return try await completeSignIn(for: authResult.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signUpWithEmail(email: String, password: String) async throws -> User {
        try ensureConfigured()

        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            return try await completeSignIn(for: authResult.user)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signOut() throws {
        guard FirebaseBootstrap.isConfigured else { return }
        try Auth.auth().signOut()
        try tokenStorage.delete(for: .firebaseIDToken)
        cachedUser.withLock { $0 = nil }
    }

    func restoreSessionProfile() async throws -> User? {
        try ensureConfigured()

        guard let userId = Auth.auth().currentUser?.uid else {
            cachedUser.withLock { $0 = nil }
            return nil
        }

        if let token = try? await Auth.auth().currentUser?.getIDToken() {
            try tokenStorage.save(token: token, for: .firebaseIDToken)
        }

        let profile = try await userRepository.fetchProfile(userId: userId)
        cachedUser.withLock { $0 = profile }
        return profile
    }

    private func completeSignIn(for user: FirebaseAuth.User) async throws -> User {
        try await persistToken(for: user)
        let profile = try await userRepository.fetchProfile(userId: user.uid)
        cachedUser.withLock { $0 = profile }
        return profile
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
