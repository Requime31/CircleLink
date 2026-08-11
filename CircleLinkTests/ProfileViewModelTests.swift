import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ProfileViewModelTests {
    @Test func canSaveRequiresNameAndInterestRange() {
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel(userRepository: users)

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
        let viewModel = makeViewModel(
            authRepository: MockAuthRepository(currentUser: nil)
        )

        await viewModel.loadProfile()

        if case let .error(message) = viewModel.state {
            #expect(message.contains("Session expired"))
        } else {
            Issue.record("Expected session error")
        }
    }

    @Test func loadProfileLoadsStatsAndPosts() async {
        let communities = MockCommunityRepository()
        communities.joinedCommunityCount = 3

        let connections = MockConnectionRepository()
        connections.matched = [
            ConnectionRequest(
                id: "a_b",
                fromUserId: "user-1",
                toUserId: "user-2",
                communityId: nil,
                status: .accepted,
                createdAt: Date()
            )
        ]

        let posts = MockProfilePostRepository()
        posts.posts = [
            ProfilePost(
                id: "p1",
                authorId: MockAuthRepository.sampleUser.id,
                text: "Hello",
                imageURL: nil,
                createdAt: Date()
            ),
            ProfilePost(
                id: "p2",
                authorId: MockAuthRepository.sampleUser.id,
                text: nil,
                imageURL: URL(string: "https://example.com/p2.jpg"),
                createdAt: Date().addingTimeInterval(-60)
            )
        ]

        let viewModel = makeViewModel(
            communityRepository: communities,
            connectionRepository: connections,
            profilePostRepository: posts
        )

        await viewModel.loadProfile()

        #expect(viewModel.circlesCount == 3)
        #expect(viewModel.connectsCount == 1)
        #expect(viewModel.postsCount == 2)
        #expect(viewModel.posts.count == 2)
    }

    @Test func createPostRefreshesGrid() async {
        let posts = MockProfilePostRepository()
        let viewModel = makeViewModel(profilePostRepository: posts)

        await viewModel.loadProfile()
        let ok = await viewModel.createPost(text: "New post", image: nil)

        #expect(ok == true)
        #expect(posts.createCallCount == 1)
        #expect(viewModel.postsCount == 1)
        #expect(viewModel.posts.first?.text == "New post")
    }

    @Test func updatePostPatchesLocalList() async {
        let posts = MockProfilePostRepository()
        let existing = ProfilePost(
            id: "p1",
            authorId: MockAuthRepository.sampleUser.id,
            text: "Old",
            imageURL: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        posts.posts = [existing]
        let viewModel = makeViewModel(profilePostRepository: posts)

        await viewModel.loadProfile()
        let ok = await viewModel.updatePost(
            existing,
            text: "Updated",
            image: nil,
            removeImage: false
        )

        #expect(ok == true)
        #expect(posts.updateCallCount == 1)
        #expect(viewModel.posts.first?.text == "Updated")
        #expect(viewModel.posts.first?.createdAt == existing.createdAt)
    }

    @Test func updatePostFailureSurfacesError() async {
        let posts = MockProfilePostRepository()
        let existing = ProfilePost(
            id: "p1",
            authorId: MockAuthRepository.sampleUser.id,
            text: "Old",
            imageURL: nil,
            createdAt: Date()
        )
        posts.posts = [existing]
        posts.updateError = FirestoreProfilePostError.notAuthor
        let viewModel = makeViewModel(profilePostRepository: posts)

        await viewModel.loadProfile()
        let ok = await viewModel.updatePost(
            existing,
            text: "Nope",
            image: nil,
            removeImage: false
        )

        #expect(ok == false)
        #expect(viewModel.postErrorMessage != nil)
        #expect(viewModel.posts.first?.text == "Old")
    }

    @Test func failedStatsRefreshKeepsPreviousValues() async {
        let communities = MockCommunityRepository()
        communities.joinedCommunityCount = 4

        let connections = MockConnectionRepository()
        connections.matched = [
            ConnectionRequest(
                id: "a_b",
                fromUserId: "user-1",
                toUserId: "user-2",
                communityId: nil,
                status: .accepted,
                createdAt: Date()
            )
        ]

        let posts = MockProfilePostRepository()
        posts.posts = [
            ProfilePost(
                id: "p1",
                authorId: MockAuthRepository.sampleUser.id,
                text: "Hello",
                imageURL: nil,
                createdAt: Date()
            )
        ]

        let viewModel = makeViewModel(
            communityRepository: communities,
            connectionRepository: connections,
            profilePostRepository: posts
        )

        await viewModel.loadProfile()
        #expect(viewModel.circlesCount == 4)
        #expect(viewModel.connectsCount == 1)
        #expect(viewModel.postsCount == 1)

        posts.fetchError = FirestoreProfilePostError.invalidData
        communities.joinedCommunityCount = 99
        await viewModel.refreshStatsAndPosts()

        #expect(viewModel.circlesCount == 99)
        #expect(viewModel.connectsCount == 1)
        #expect(viewModel.postsCount == 1)
        #expect(viewModel.posts.count == 1)
    }

    @Test func createPostKeepsLocalPostWhenRefreshFails() async {
        let posts = MockProfilePostRepository()
        posts.failReadsAfterCreate = true
        let viewModel = makeViewModel(profilePostRepository: posts)

        await viewModel.loadProfile()
        let ok = await viewModel.createPost(text: "Kept locally", image: nil)

        #expect(ok == true)
        #expect(viewModel.postsCount == 1)
        #expect(viewModel.posts.first?.text == "Kept locally")
    }

    @Test func formattedCountUsesCompactSuffix() {
        #expect(ProfileViewModel.formattedCount(45) == "45")
        #expect(ProfileViewModel.formattedCount(1_200) == "1.2k")
        #expect(ProfileViewModel.formattedCount(8_200) == "8.2k")
    }

    @Test func saveProfileSuccessUpdatesRepositoryAndCallback() async {
        let users = MockUserRepository()
        var savedUser: User?
        let viewModel = makeViewModel(
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
        let viewModel = makeViewModel(userRepository: users)

        await viewModel.saveProfile()

        #expect(users.updateProfileCallCount == 0)
        if case .error = viewModel.saveState {
            // ok
        } else {
            Issue.record("Expected validation error on save")
        }
    }

    private func makeViewModel(
        authRepository: AuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
        userRepository: UserRepository = MockUserRepository(),
        communityRepository: CommunityRepository = MockCommunityRepository(),
        connectionRepository: ConnectionRepository = MockConnectionRepository(),
        profilePostRepository: ProfilePostRepository = MockProfilePostRepository(),
        onProfileSaved: ((User) -> Void)? = nil
    ) -> ProfileViewModel {
        ProfileViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            communityRepository: communityRepository,
            connectionRepository: connectionRepository,
            profilePostRepository: profilePostRepository,
            onProfileSaved: onProfileSaved
        )
    }
}
