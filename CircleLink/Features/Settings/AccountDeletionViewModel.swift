import Combine
import Foundation

@MainActor
final class AccountDeletionViewModel: ObservableObject {
    @Published private(set) var isDeleting = false
    @Published private(set) var isReauthenticating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsReauthentication = false
    @Published var password = ""

    let reauthenticationMethod: ReauthenticationMethod

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let now: () -> Date
    private let onDeactivated: (String) async -> Void

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        now: @escaping () -> Date = Date.init,
        onDeactivated: @escaping (String) async -> Void
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.now = now
        self.onDeactivated = onDeactivated
        reauthenticationMethod = authRepository.reauthenticationMethod
    }

    func requestDeletion() async {
        guard !isDeleting, !isReauthenticating, let userID = authRepository.currentUser?.id else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await userRepository.requestAccountDeletion(now: now())
            guard authRepository.currentUser?.id == userID else { return }
            await onDeactivated(userID)
        } catch AccountLifecycleError.requiresRecentLogin {
            guard authRepository.currentUser?.id == userID else { return }
            needsReauthentication = true
        } catch {
            guard authRepository.currentUser?.id == userID else { return }
            errorMessage = error.localizedDescription
        }
    }

    func reauthenticateAndRetry() async {
        guard needsReauthentication, !isDeleting, !isReauthenticating,
              let userID = authRepository.currentUser?.id else { return }
        if case .email = reauthenticationMethod, password.isEmpty {
            errorMessage = "Enter your password to continue."
            return
        }

        isReauthenticating = true
        errorMessage = nil
        defer { isReauthenticating = false }
        do {
            switch reauthenticationMethod {
            case .apple:
                try await authRepository.reauthenticateWithApple()
            case .email:
                let submittedPassword = password
                password = ""
                try await authRepository.reauthenticateWithEmail(password: submittedPassword)
            case .unavailable:
                throw AccountLifecycleError.requiresRecentLogin
            }
            guard authRepository.currentUser?.id == userID else { return }
            needsReauthentication = false
            isReauthenticating = false
            await requestDeletion()
        } catch {
            guard authRepository.currentUser?.id == userID else { return }
            errorMessage = error.localizedDescription
        }
    }
}
