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

    init(authRepository: AuthRepository, onAuthenticated: @escaping (User) -> Void) {
        self.authRepository = authRepository
        self.onAuthenticated = onAuthenticated
    }

    func signInWithApple() async {
        state = .loading
        do {
            let user = try await authRepository.signInWithApple()
            state = .loaded(true)
            onAuthenticated(user)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func signInWithEmail() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            state = .error("Enter email and password.")
            return
        }

        state = .loading
        do {
            let user = try await authRepository.signInWithEmail(email: trimmedEmail, password: password)
            state = .loaded(true)
            onAuthenticated(user)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func signUpWithEmail() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            state = .error("Enter email and password.")
            return
        }

        state = .loading
        do {
            let user = try await authRepository.signUpWithEmail(email: trimmedEmail, password: password)
            state = .loaded(true)
            onAuthenticated(user)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        email = ""
        password = ""
        state = .idle
    }
}
