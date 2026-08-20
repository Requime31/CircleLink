import Combine
import Foundation

/// Data flow:
/// User tap Sign In
///   → AuthView
///   → AuthViewModel.signInWithApple() / signInWithEmail()
///   → AuthRepository (FirebaseAuthRepository)
///   → Firebase Auth
///   → Keychain (Firebase ID token)
///   → onAuthenticated(User)
///   → AppCoordinator route update
///   → UI transition (Age Gate / Profile Setup / MainTab)
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var state: ViewState<Bool> = .idle

    private let authRepository: AuthRepository
    let onAuthenticated: (User) -> Void
    private var isAuthenticating = false
    private var authenticationGeneration = 0

    init(authRepository: AuthRepository, onAuthenticated: @escaping (User) -> Void) {
        self.authRepository = authRepository
        self.onAuthenticated = onAuthenticated
    }

    func signInWithApple() async {
        guard let generation = beginAuthentication() else { return }
        state = .loading
        do {
            let user = try await authRepository.signInWithApple()
            guard finishAuthentication(generation) else { return }
            state = .loaded(true)
            onAuthenticated(user)
        } catch {
            guard finishAuthentication(generation) else { return }
            state = .error(error.localizedDescription)
        }
    }

    func signInWithEmail() async {
        guard !isAuthenticating else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            state = .error("Enter email and password.")
            return
        }

        guard let generation = beginAuthentication() else { return }
        state = .loading
        do {
            let user = try await authRepository.signInWithEmail(email: trimmedEmail, password: password)
            guard finishAuthentication(generation) else { return }
            state = .loaded(true)
            onAuthenticated(user)
        } catch {
            guard finishAuthentication(generation) else { return }
            state = .error(error.localizedDescription)
        }
    }

    func signUpWithEmail() async {
        guard !isAuthenticating else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            state = .error("Enter email and password.")
            return
        }

        guard let generation = beginAuthentication() else { return }
        state = .loading
        do {
            let user = try await authRepository.signUpWithEmail(email: trimmedEmail, password: password)
            guard finishAuthentication(generation) else { return }
            state = .loaded(true)
            onAuthenticated(user)
        } catch {
            guard finishAuthentication(generation) else { return }
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        authenticationGeneration += 1
        isAuthenticating = false
        email = ""
        password = ""
        state = .idle
    }

    private func beginAuthentication() -> Int? {
        guard !isAuthenticating else { return nil }
        isAuthenticating = true
        authenticationGeneration += 1
        return authenticationGeneration
    }

    private func finishAuthentication(_ generation: Int) -> Bool {
        guard generation == authenticationGeneration else { return false }
        isAuthenticating = false
        return true
    }
}
