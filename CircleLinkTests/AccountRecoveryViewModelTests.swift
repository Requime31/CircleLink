import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AccountRecoveryViewModelTests {
    @Test func restoreRefetchesAndRoutesUsingActiveProfile() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let profile = deactivatedProfile(now: now)
        let auth = MockAuthRepository(currentUser: profile)
        let users = MockUserRepository()
        users.profiles[profile.id] = profile
        var routedUser: User?
        let viewModel = AccountRecoveryViewModel(
            profile: profile,
            authRepository: auth,
            userRepository: users,
            now: { now },
            onRestored: { routedUser = $0 },
            onSignOut: { _ in }
        )

        await viewModel.restore()

        #expect(users.restoreAccountCallCount == 1)
        let restored = try #require(routedUser)
        #expect(restored.accountState == .active)
        #expect(AppCoordinator.route(for: restored) == .mainTab)
    }

    @Test func expiredAccountCannotRestore() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var profile = deactivatedProfile(now: now)
        profile.scheduledDeletionAt = now
        let auth = MockAuthRepository(currentUser: profile)
        let users = MockUserRepository()
        let viewModel = AccountRecoveryViewModel(
            profile: profile,
            authRepository: auth,
            userRepository: users,
            now: { now },
            onRestored: { _ in },
            onSignOut: { _ in }
        )

        await viewModel.restore()

        #expect(viewModel.state == .expired)
        #expect(users.restoreAccountCallCount == 0)
    }

    @Test func sessionSwapDuringRestoreDoesNotRoute() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let profile = deactivatedProfile(now: now)
        let auth = MockAuthRepository(currentUser: profile)
        let users = MockUserRepository()
        users.profiles[profile.id] = profile
        users.shouldSuspendLifecycle = true
        var routeCount = 0
        let viewModel = AccountRecoveryViewModel(
            profile: profile,
            authRepository: auth,
            userRepository: users,
            now: { now },
            onRestored: { _ in routeCount += 1 },
            onSignOut: { _ in }
        )

        let task = Task { await viewModel.restore() }
        while !users.hasPendingLifecycleOperation { await Task.yield() }
        auth.currentUser = User(id: "other", displayName: "Other")
        users.lifecycleCurrentUserID = "other"
        users.resumeLifecycleOperation()
        await task.value

        #expect(routeCount == 0)
    }

    @Test func coordinatorAlwaysRoutesDeactivatedProfileToRecovery() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(AppCoordinator.route(for: deactivatedProfile(now: now)) == .accountRecovery)
    }

    private func deactivatedProfile(now: Date) -> User {
        var user = MockAuthRepository.sampleUser
        user.accountState = .deactivated
        user.deletionRequestedAt = now
        user.scheduledDeletionAt = now.addingTimeInterval(86_400)
        return user
    }
}
