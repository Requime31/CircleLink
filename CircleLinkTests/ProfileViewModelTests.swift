import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ProfileViewModelTests {
    @Test func canSaveRequiresNameAndInterestRange() {
        let viewModel = ProfileViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: MockUserRepository()
        )

        #expect(viewModel.canSave == false)
        #expect(viewModel.validationMessage == "Enter a display name.")

        viewModel.displayName = "Roman"
        #expect(viewModel.canSave == false)
        #expect(viewModel.validationMessage?.contains("at least") == true)

        viewModel.selectedInterests = ["Sports", "Music", "Art"]
        #expect(viewModel.canSave == true)
        #expect(viewModel.validationMessage == nil)
    }

    @Test func toggleInterestRespectsMaxLimit() {
        let viewModel = ProfileViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: MockUserRepository()
        )

        for interest in ["Sports", "Music", "Art", "Tech", "Travel"] {
            viewModel.toggleInterest(interest)
        }
        #expect(viewModel.selectedInterests.count == User.maxInterests)

        viewModel.toggleInterest("Food")
        #expect(viewModel.selectedInterests.contains("Food") == false)
        #expect(viewModel.selectedInterests.count == User.maxInterests)

        viewModel.toggleInterest("Sports")
        #expect(viewModel.selectedInterests.contains("Sports") == false)
    }

    @Test func loadProfileSuccessAppliesFields() async {
        let users = MockUserRepository()
        let viewModel = ProfileViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: users
        )

        await viewModel.loadProfile()

        #expect(viewModel.displayName == "Test User")
        #expect(viewModel.selectedInterests.contains("Sports"))
        if case .loaded = viewModel.state {
            // ok
        } else {
            Issue.record("Expected loaded profile state")
        }
    }

    @Test func loadProfileWithoutSessionShowsError() async {
        let viewModel = ProfileViewModel(
            authRepository: MockAuthRepository(currentUser: nil),
            userRepository: MockUserRepository()
        )

        await viewModel.loadProfile()

        if case let .error(message) = viewModel.state {
            #expect(message.contains("Session expired"))
        } else {
            Issue.record("Expected session error")
        }
    }

    @Test func saveProfileSuccessUpdatesRepositoryAndCallback() async {
        let users = MockUserRepository()
        var savedUser: User?
        let viewModel = ProfileViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: users,
            onProfileSaved: { savedUser = $0 }
        )

        await viewModel.loadProfile()
        viewModel.displayName = "  New Name  "
        viewModel.selectedInterests = ["Sports", "Music", "Art"]

        await viewModel.saveProfile()

        #expect(users.updateProfileCallCount == 1)
        #expect(users.lastUpdatedUser?.displayName == "New Name")
        #expect(savedUser?.displayName == "New Name")
        if case .loaded = viewModel.saveState {
            // ok
        } else {
            Issue.record("Expected loaded save state")
        }
    }

    @Test func saveProfileWhenInvalidDoesNotCallRepository() async {
        let users = MockUserRepository()
        let viewModel = ProfileViewModel(
            authRepository: MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
            userRepository: users
        )

        await viewModel.saveProfile()

        #expect(users.updateProfileCallCount == 0)
        if case .error = viewModel.saveState {
            // ok
        } else {
            Issue.record("Expected validation error on save")
        }
    }
}
