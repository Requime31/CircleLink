import Combine
import Foundation

@MainActor
final class AccountRecoveryViewModel: ObservableObject {
    enum State: Equatable {
        case available
        case expired
        case restoring
        case error(String)
    }

    @Published private(set) var profile: User
    @Published private(set) var state: State
    @Published private(set) var isSigningOut = false

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let now: () -> Date
    private let onRestored: (User) -> Void
    private let onSignOut: (String) async -> Void

    init(
        profile: User,
        authRepository: AuthRepository,
        userRepository: UserRepository,
        now: @escaping () -> Date = Date.init,
        onRestored: @escaping (User) -> Void,
        onSignOut: @escaping (String) async -> Void
    ) {
        self.profile = profile
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.now = now
        self.onRestored = onRestored
        self.onSignOut = onSignOut
        state = Self.isExpired(profile: profile, now: now()) ? .expired : .available
    }

    var deadline: Date? { profile.scheduledDeletionAt }
    var hasExpired: Bool { Self.isExpired(profile: profile, now: now()) }
    var canRestore: Bool { !hasExpired && (state == .available || isErrorBeforeDeadline) }

    func refreshDeadlineState() {
        guard state != .restoring else { return }
        state = Self.isExpired(profile: profile, now: now()) ? .expired : .available
    }

    func restore() async {
        guard canRestore, let expectedUserID = authRepository.currentUser?.id,
              expectedUserID == profile.id else { return }
        guard !Self.isExpired(profile: profile, now: now()) else {
            state = .expired
            return
        }

        state = .restoring
        do {
            try await userRepository.restoreAccount()
            guard authRepository.currentUser?.id == expectedUserID else { return }
            let restored = try await userRepository.fetchProfile(userId: expectedUserID)
            guard authRepository.currentUser?.id == expectedUserID else { return }
            profile = restored
            onRestored(restored)
        } catch {
            guard authRepository.currentUser?.id == expectedUserID else { return }
            state = .error(error.localizedDescription)
        }
    }

    func signOut() async {
        guard !isSigningOut, state != .restoring,
              authRepository.currentUser?.id == profile.id else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        await onSignOut(profile.id)
    }

    private var isErrorBeforeDeadline: Bool {
        if case .error = state { return !Self.isExpired(profile: profile, now: now()) }
        return false
    }

    private static func isExpired(profile: User, now: Date) -> Bool {
        guard let deadline = profile.scheduledDeletionAt else { return true }
        return now >= deadline
    }
}
