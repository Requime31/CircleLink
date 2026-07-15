import Combine
import Foundation

@MainActor
final class AgeGateViewModel: ObservableObject {
    @Published var isAgeConfirmed = false
    @Published private(set) var state: ViewState<Bool> = .idle

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    let onAgeConfirmed: (User) -> Void

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        onAgeConfirmed: @escaping (User) -> Void
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.onAgeConfirmed = onAgeConfirmed
    }

    var canContinue: Bool {
        isAgeConfirmed
    }

    func confirmAge() async {
        guard isAgeConfirmed else { return }

        state = .loading
        do {
            try await userRepository.confirmAge()
            guard let userId = authRepository.currentUser?.id else {
                state = .error("Session expired. Please sign in again.")
                return
            }
            let profile = try await userRepository.fetchProfile(userId: userId)
            state = .loaded(true)
            onAgeConfirmed(profile)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        isAgeConfirmed = false
        state = .idle
    }
}
