import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AuthViewModelTests {
    @Test func signInWithEmailSuccessCallsOnAuthenticated() async {
        let auth = MockAuthRepository()
        var authenticatedUser: User?
        let viewModel = AuthViewModel(authRepository: auth) { user in
            authenticatedUser = user
        }

        viewModel.email = "  test@example.com "
        viewModel.password = "secret"

        await viewModel.signInWithEmail()

        #expect(auth.signInWithEmailCallCount == 1)
        #expect(auth.lastEmail == "test@example.com")
        #expect(authenticatedUser?.id == MockAuthRepository.sampleUser.id)
        if case .loaded(true) = viewModel.state {
            // ok
        } else {
            Issue.record("Expected loaded state, got \(viewModel.state)")
        }
    }

    @Test func signInWithEmailEmptyFieldsShowsError() async {
        let auth = MockAuthRepository()
        let viewModel = AuthViewModel(authRepository: auth) { _ in }

        await viewModel.signInWithEmail()

        #expect(auth.signInWithEmailCallCount == 0)
        if case let .error(message) = viewModel.state {
            #expect(message.contains("email"))
        } else {
            Issue.record("Expected validation error")
        }
    }

    @Test func signInWithEmailPropagatesRepositoryError() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Bad credentials" }
        }

        let auth = MockAuthRepository()
        auth.signInWithEmailResult = .failure(Boom())
        let viewModel = AuthViewModel(authRepository: auth) { _ in }
        viewModel.email = "a@b.com"
        viewModel.password = "x"

        await viewModel.signInWithEmail()

        if case let .error(message) = viewModel.state {
            #expect(message == "Bad credentials")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func signUpWithEmailSuccessCallsOnAuthenticated() async {
        let auth = MockAuthRepository()
        var authenticatedUser: User?
        let viewModel = AuthViewModel(authRepository: auth) { user in
            authenticatedUser = user
        }

        viewModel.email = "new@example.com"
        viewModel.password = "secret123"

        await viewModel.signUpWithEmail()

        #expect(auth.signUpWithEmailCallCount == 1)
        #expect(auth.lastEmail == "new@example.com")
        #expect(authenticatedUser?.id == MockAuthRepository.sampleUser.id)
        if case .loaded(true) = viewModel.state {
            // ok
        } else {
            Issue.record("Expected loaded state after sign up")
        }
    }

    @Test func signUpWithEmailEmptyFieldsShowsError() async {
        let auth = MockAuthRepository()
        let viewModel = AuthViewModel(authRepository: auth) { _ in }

        await viewModel.signUpWithEmail()

        #expect(auth.signUpWithEmailCallCount == 0)
        if case let .error(message) = viewModel.state {
            #expect(message.contains("email"))
        } else {
            Issue.record("Expected validation error")
        }
    }

    @Test func signInWithApplePropagatesRepositoryError() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Apple failed" }
        }

        let auth = MockAuthRepository()
        auth.signInWithAppleResult = .failure(Boom())
        let viewModel = AuthViewModel(authRepository: auth) { _ in }

        await viewModel.signInWithApple()

        if case let .error(message) = viewModel.state {
            #expect(message == "Apple failed")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func resetFormClearsFieldsAndState() async {
        let auth = MockAuthRepository()
        let viewModel = AuthViewModel(authRepository: auth) { _ in }
        viewModel.email = "a@b.com"
        viewModel.password = "x"
        await viewModel.signInWithEmail()

        viewModel.resetForm()

        #expect(viewModel.email.isEmpty)
        #expect(viewModel.password.isEmpty)
        if case .idle = viewModel.state {
            // ok
        } else {
            Issue.record("Expected idle after reset")
        }
    }
}
