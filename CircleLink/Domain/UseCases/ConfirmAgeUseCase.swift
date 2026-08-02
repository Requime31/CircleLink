import Foundation

nonisolated enum ConfirmAgeUseCaseError: LocalizedError, Equatable {
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .sessionExpired:
            return "Session expired. Please sign in again."
        }
    }
}

/// Confirms age on the user profile, then reloads the authenticated profile.
/// Multi-repo: `UserRepository` + session from `AuthRepository`.
struct ConfirmAgeUseCase: Sendable {
    private let userRepository: UserRepository
    private let authRepository: AuthRepository

    init(userRepository: UserRepository, authRepository: AuthRepository) {
        self.userRepository = userRepository
        self.authRepository = authRepository
    }

    /// Writes age confirmation, then returns the refreshed profile for navigation.
    func execute() async throws -> User {
        try await userRepository.confirmAge()
        guard let userId = authRepository.currentUser?.id else {
            throw ConfirmAgeUseCaseError.sessionExpired
        }
        return try await userRepository.fetchProfile(userId: userId)
    }
}
