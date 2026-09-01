import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AccountDeletionViewModelTests {
    @Test func successfulRequestDeactivatesAndFinishesSession() async {
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        let users = MockUserRepository()
        var completionCount = 0
        let instant = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = AccountDeletionViewModel(
            authRepository: auth,
            userRepository: users,
            now: { instant },
            onDeactivated: { _ in completionCount += 1 }
        )

        await viewModel.requestDeletion()

        #expect(users.requestAccountDeletionCallCount == 1)
        #expect(users.profiles["user-1"]?.accountState == .deactivated)
        #expect(completionCount == 1)
        #expect(!viewModel.isDeleting)
    }

    @Test func errorIsPresentedAndDoesNotFinishSession() async {
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        let users = MockUserRepository()
        users.accountDeletionError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Offline"])
        var completionCount = 0
        let viewModel = AccountDeletionViewModel(authRepository: auth, userRepository: users) { _ in
            completionCount += 1
        }

        await viewModel.requestDeletion()

        #expect(viewModel.errorMessage == "Offline")
        #expect(completionCount == 0)
    }

    @Test func duplicateTapStartsOnlyOneRequest() async {
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        let users = MockUserRepository()
        users.shouldSuspendLifecycle = true
        let viewModel = AccountDeletionViewModel(authRepository: auth, userRepository: users) { _ in }

        let first = Task { await viewModel.requestDeletion() }
        while !users.hasPendingLifecycleOperation { await Task.yield() }
        await viewModel.requestDeletion()
        users.resumeLifecycleOperation()
        await first.value

        #expect(users.requestAccountDeletionCallCount == 1)
    }

    @Test func recentLoginUsesEmailPasswordThenRetries() async {
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        auth.reauthenticationMethod = .email(address: "test@example.com")
        let users = MockUserRepository()
        users.accountDeletionError = AccountLifecycleError.requiresRecentLogin
        var completionCount = 0
        let viewModel = AccountDeletionViewModel(authRepository: auth, userRepository: users) { _ in
            completionCount += 1
        }

        await viewModel.requestDeletion()
        #expect(viewModel.needsReauthentication)
        users.accountDeletionError = nil
        viewModel.password = "one-time-password"
        await viewModel.reauthenticateAndRetry()

        #expect(auth.reauthenticateWithEmailCallCount == 1)
        #expect(auth.lastPassword == "one-time-password")
        #expect(viewModel.password.isEmpty)
        #expect(users.requestAccountDeletionCallCount == 2)
        #expect(completionCount == 1)
    }

    @Test func sessionSwapSuppressesStaleCompletionAndError() async {
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        let users = MockUserRepository()
        users.shouldSuspendLifecycle = true
        var completionCount = 0
        let viewModel = AccountDeletionViewModel(authRepository: auth, userRepository: users) { _ in
            completionCount += 1
        }

        let task = Task { await viewModel.requestDeletion() }
        while !users.hasPendingLifecycleOperation { await Task.yield() }
        auth.currentUser = User(id: "other", displayName: "Other")
        users.lifecycleCurrentUserID = "other"
        users.resumeLifecycleOperation()
        await task.value

        #expect(completionCount == 0)
        #expect(viewModel.errorMessage == nil)
    }
}
