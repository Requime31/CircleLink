import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AgeGateViewModelTests {
    private func makeViewModel(
        auth: MockAuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
        users: MockUserRepository = MockUserRepository(),
        onAgeConfirmed: @escaping (User) -> Void = { _ in }
    ) -> (AgeGateViewModel, MockUserRepository) {
        let viewModel = AgeGateViewModel(
            confirmAge: ConfirmAgeUseCase(userRepository: users, authRepository: auth),
            onAgeConfirmed: onAgeConfirmed
        )
        return (viewModel, users)
    }

    @Test func canContinueMatchesCheckbox() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.canContinue == false)
        viewModel.isAgeConfirmed = true
        #expect(viewModel.canContinue == true)
    }

    @Test func confirmAgeWithoutCheckboxIsNoOp() async {
        let (viewModel, users) = makeViewModel()

        await viewModel.confirmAge()

        #expect(users.confirmAgeCallCount == 0)
        if case .idle = viewModel.state {
            // ok
        } else {
            Issue.record("Expected idle when checkbox unchecked")
        }
    }

    @Test func confirmAgeSuccessFetchesProfileAndCallbacks() async {
        var confirmedUser: User?
        let (viewModel, users) = makeViewModel { confirmedUser = $0 }
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
        let (viewModel, users) = makeViewModel(
            auth: MockAuthRepository(currentUser: nil)
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
        let (viewModel, _) = makeViewModel(users: users)
        viewModel.isAgeConfirmed = true

        await viewModel.confirmAge()

        if case let .error(message) = viewModel.state {
            #expect(message == "Age confirm failed")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func resetFormClearsCheckboxAndState() async {
        let (viewModel, _) = makeViewModel()
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
