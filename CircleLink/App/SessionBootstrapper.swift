import Foundation

/// Restores or fetches the signed-in profile used to choose the root route.
@MainActor
struct SessionBootstrapper {
    enum Outcome: Equatable {
        case authenticated(User)
        case signedOut
    }

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let restoreAuthenticatedProfile: () async throws -> User?

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        restoreAuthenticatedProfile: @escaping () async throws -> User?
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.restoreAuthenticatedProfile = restoreAuthenticatedProfile
    }

    func bootstrap() async -> Outcome {
        do {
            if let profile = try await restoreAuthenticatedProfile() {
                return .authenticated(profile)
            }
        } catch {
            return .signedOut
        }

        guard let user = authRepository.currentUser else {
            return .signedOut
        }

        do {
            let profile = try await userRepository.fetchProfile(userId: user.id)
            return .authenticated(profile)
        } catch {
            return .signedOut
        }
    }
}
