import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AgeGateViewModelTests {
    @Test func canContinueRequiresValidAdultBirthYear() {
        let viewModel = makeViewModel()

        #expect(viewModel.canContinue == false)

        viewModel.birthYearText = "2010"
        #expect(viewModel.canContinue == false)

        viewModel.birthYearText = "1990"
        #expect(viewModel.canContinue == true)
    }

    @Test func confirmAgeWithoutYearShowsErrorAndDoesNotCallRepository() async {
        let users = MockUserRepository()
        let viewModel = makeViewModel(userRepository: users)

        await viewModel.confirmAge()

        #expect(users.confirmAgeCallCount == 0)
        if case let .error(message) = viewModel.state {
            #expect(message.lowercased().contains("year"))
        } else {
            Issue.record("Expected year validation error")
        }
    }

    @Test func confirmAgeUnder18ShowsError() async {
        let users = MockUserRepository()
        let viewModel = makeViewModel(userRepository: users)
        viewModel.birthYearText = String(Calendar.current.component(.year, from: Date()) - 10)

        await viewModel.confirmAge()

        #expect(users.confirmAgeCallCount == 0)
        if case let .error(message) = viewModel.state {
            #expect(message.contains("18"))
        } else {
            Issue.record("Expected under-18 error")
        }
    }

    @Test func confirmAgeSuccessFetchesProfileAndCallbacks() async {
        let users = MockUserRepository()
        var confirmedUser: User?
        let viewModel = makeViewModel(userRepository: users) { confirmedUser = $0 }
        viewModel.birthYearText = "1990"

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
        viewModel.birthYearText = "1990"

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
        let viewModel = makeViewModel(userRepository: users)
        viewModel.birthYearText = "1990"

        await viewModel.confirmAge()

        if case let .error(message) = viewModel.state {
            #expect(message == "Age confirm failed")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func resetFormClearsYearAndState() async {
        let viewModel = makeViewModel()
        viewModel.birthYearText = "1990"
        await viewModel.confirmAge()

        viewModel.resetForm()

        #expect(viewModel.birthYearText.isEmpty)
        if case .idle = viewModel.state {
            // ok
        } else {
            Issue.record("Expected idle after reset")
        }
    }

    private func makeViewModel(
        userRepository: MockUserRepository = MockUserRepository(),
        onAgeConfirmed: @escaping (User) -> Void = { _ in }
    ) -> AgeGateViewModel {
        AgeGateViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: userRepository,
            onAgeConfirmed: onAgeConfirmed
        )
    }
}
