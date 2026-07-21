import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AgeGateViewModelTests {
    @Test func canContinueMatchesCheckbox() {
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: MockUserRepository(),
            onAgeConfirmed: { _ in }
        )

        #expect(viewModel.canContinue == false)
        viewModel.isAgeConfirmed = true
        #expect(viewModel.canContinue == true)
    }

    @Test func confirmAgeWithoutCheckboxIsNoOp() async {
        let users = MockUserRepository()
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: users,
            onAgeConfirmed: { _ in }
        )

        await viewModel.confirmAge()

        #expect(users.confirmAgeCallCount == 0)
        if case .idle = viewModel.state {
            // ok
        } else {
            Issue.record("Expected idle when checkbox unchecked")
        }
    }

    @Test func confirmAgeSuccessFetchesProfileAndCallbacks() async {
        let users = MockUserRepository()
        var confirmedUser: User?
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: users,
            onAgeConfirmed: { confirmedUser = $0 }
        )
        viewModel.isAgeConfirmed = true

        await viewModel.confirmAge()

        #expect(users.confirmAgeCallCount == 1)
        #expect(confirmedUser?.id == "user-1")
        if case .loaded(true) = viewModel.state {
            // ok
        } else {
            Issue.record("Expected loaded state after confirm")
        }
    }

    @Test func confirmAgeWithoutSessionShowsError() async {
        let users = MockUserRepository()
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: nil),
            userRepository: users,
            onAgeConfirmed: { _ in }
        )
        viewModel.isAgeConfirmed = true

        await viewModel.confirmAge()

        #expect(users.confirmAgeCallCount == 1)
        if case let .error(message) = viewModel.state {
            #expect(message.contains("Session expired"))
        } else {
            Issue.record("Expected session error")
        }
    }

    @Test func confirmAgePropagatesRepositoryError() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Age confirm failed" }
        }

        let users = MockUserRepository()
        users.confirmAgeError = Boom()
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: users,
            onAgeConfirmed: { _ in }
        )
        viewModel.isAgeConfirmed = true

        await viewModel.confirmAge()

        if case let .error(message) = viewModel.state {
            #expect(message == "Age confirm failed")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func resetFormClearsCheckboxAndState() async {
        let viewModel = AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: MockUserRepository(),
            onAgeConfirmed: { _ in }
        )
        viewModel.isAgeConfirmed = true
        await viewModel.confirmAge()

        viewModel.resetForm()

        #expect(viewModel.isAgeConfirmed == false)
        if case .idle = viewModel.state {
            // ok
        } else {
            Issue.record("Expected idle after reset")
        }
    }
}
