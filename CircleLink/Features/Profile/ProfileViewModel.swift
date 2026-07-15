import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var state: ViewState<Bool> = .idle

    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    func signOut() -> Bool {
        do {
            try authRepository.signOut()
            state = .loaded(true)
            return true
        } catch {
            state = .error(error.localizedDescription)
            return false
        }
    }
}
