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

    @Test func loadProfilePrefillsPersistedBirthDateAndCalculatedAge() async {
        let users = MockUserRepository()
        var user = MockAuthRepository.sampleUser
        user.birthDate = Self.persistedDate(1990, 4, 12)
        user.age = 36
        users.profiles[user.id] = user
        let viewModel = makeViewModel(userRepository: users, now: Self.localDate(2026, 8, 25))

        await viewModel.loadProfile()

        #expect(viewModel.usesBirthDate)
        #expect(viewModel.calculatedAge == 36)
        #expect(Self.calendar.isDate(viewModel.selectedBirthDate, inSameDayAs: Self.localDate(1990, 4, 12)))
    }

    @Test func legacyConfirmedProfileKeepsEditableAgeFallback() async {
        let users = MockUserRepository()
        var user = MockAuthRepository.sampleUser
        user.birthDate = nil
        user.age = 42
        users.profiles[user.id] = user
        let viewModel = makeViewModel(userRepository: users)

        await viewModel.loadProfile()

        #expect(!viewModel.usesBirthDate)
        #expect(viewModel.ageText == "42")
        viewModel.ageText = "43"
        #expect(viewModel.canSave)
        await viewModel.saveProfile()
        #expect(users.lastUpdatedUser?.age == 43)
    }

    @Test func birthDateSaveSessionChangeReturnsToIdle() async {
        let users = MockUserRepository()
        users.shouldSuspendBirthDateConfirmation = true
        let auth = MockAuthRepository(currentUser: MockAuthRepository.sampleUser)
        var user = MockAuthRepository.sampleUser
        user.birthDate = Self.persistedDate(1990, 4, 12)
        user.age = 36
        users.profiles[user.id] = user
        let viewModel = makeViewModel(authRepository: auth, userRepository: users, now: Self.localDate(2026, 8, 25))
        await viewModel.loadProfile()
        viewModel.selectedBirthDate = Self.localDate(1991, 4, 12)

        let task = Task { await viewModel.saveProfile(confirmBirthDateChange: true) }
        while !users.hasPendingBirthDateConfirmation { await Task.yield() }
        auth.currentUser = nil
        users.resumeBirthDateConfirmation()
        await task.value

        if case .idle = viewModel.saveState {} else { Issue.record("Expected idle after session change") }
    }

    @Test func birthDateSaveCancellationReturnsToIdle() async {
        let users = MockUserRepository()
        users.shouldSuspendBirthDateConfirmation = true
        var user = MockAuthRepository.sampleUser
        user.birthDate = Self.persistedDate(1990, 4, 12)
        user.age = 36
        users.profiles[user.id] = user
        let viewModel = makeViewModel(userRepository: users, now: Self.localDate(2026, 8, 25))
        await viewModel.loadProfile()
        viewModel.selectedBirthDate = Self.localDate(1991, 4, 12)

        let task = Task { await viewModel.saveProfile(confirmBirthDateChange: true) }
        while !users.hasPendingBirthDateConfirmation { await Task.yield() }
        task.cancel()
        users.resumeBirthDateConfirmation()
        await task.value

        if case .idle = viewModel.saveState {} else { Issue.record("Expected idle after cancellation") }
    }

    @Test func editingBirthDateRecalculatesAgeAndRequiresConfirmation() async {
        let users = MockUserRepository()
        var user = MockAuthRepository.sampleUser
        user.birthDate = Self.persistedDate(1990, 4, 12)
        user.age = 36
        users.profiles[user.id] = user
        let viewModel = makeViewModel(userRepository: users, now: Self.localDate(2026, 8, 25))
        await viewModel.loadProfile()
        viewModel.selectedBirthDate = Self.localDate(1991, 9, 1)

        #expect(viewModel.hasBirthDateChange)
        #expect(viewModel.calculatedAge == 34)
        await viewModel.saveProfile()
        #expect(users.confirmAgeBirthDateCallCount == 0)

        await viewModel.saveProfile(confirmBirthDateChange: true)
        #expect(users.confirmAgeBirthDateCallCount == 1)
        #expect(users.updateProfileCallCount == 1)
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

    @Test func unchangedPostSaveKeepsExistingImage() async {
        let (viewModel, posts, existing) = await makeLoadedPostViewModel(text: "Same", hasImage: true)

        let ok = await viewModel.updatePost(existing, text: "Same", image: nil, removeImage: false)

        #expect(ok)
        #expect(posts.lastUpdateImage == nil)
        #expect(!posts.lastUpdateRemoveImage)
        #expect(viewModel.posts.first?.imageURL == existing.imageURL)
    }

    @Test func replacingPostPhotoForwardsNewImage() async {
        let (viewModel, posts, existing) = await makeLoadedPostViewModel(text: "Photo", hasImage: true)
        let replacement = Data([1, 2, 3])

        let ok = await viewModel.updatePost(existing, text: "Photo", image: replacement, removeImage: false)

        #expect(ok)
        #expect(posts.lastUpdateImage == replacement)
        #expect(!posts.lastUpdateRemoveImage)
    }

    @Test func removingPostPhotoForwardsRemoval() async {
        let (viewModel, posts, existing) = await makeLoadedPostViewModel(text: "Photo", hasImage: true)

        let ok = await viewModel.updatePost(existing, text: "Photo", image: nil, removeImage: true)

        #expect(ok)
        #expect(posts.lastUpdateRemoveImage)
        #expect(viewModel.posts.first?.imageURL == nil)
    }

    @Test func emptyPostAfterPhotoRemovalIsRejected() async {
        let (viewModel, _, existing) = await makeLoadedPostViewModel(text: nil, hasImage: true)

        let ok = await viewModel.updatePost(existing, text: "   ", image: nil, removeImage: true)

        #expect(!ok)
        #expect(viewModel.postErrorMessage != nil)
        #expect(viewModel.posts.first == existing)
    }

    @Test func duplicatePostSaveIsIgnoredWhileUpdateRuns() async {
        let (viewModel, posts, existing) = await makeLoadedPostViewModel(text: "Old", hasImage: false)
        posts.shouldSuspendUpdate = true

        let first = Task { await viewModel.updatePost(existing, text: "First", image: nil, removeImage: false) }
        while !posts.hasPendingUpdate { await Task.yield() }
        let duplicate = await viewModel.updatePost(existing, text: "Second", image: nil, removeImage: false)
        posts.resumeUpdate()

        #expect(!duplicate)
        #expect(await first.value)
        #expect(posts.updateCallCount == 1)
        #expect(viewModel.posts.first?.text == "First")
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

    @Test func resetFormClearsAllUserSpecificFields() async {
        let viewModel = makeViewModel()
        await viewModel.loadProfile()
        viewModel.aboutMe = "Private biography"
        viewModel.ageText = "42"

        viewModel.resetForm()

        #expect(viewModel.displayName.isEmpty)
        #expect(viewModel.aboutMe.isEmpty)
        #expect(viewModel.ageText.isEmpty)
        #expect(viewModel.profile == nil)
        #expect(viewModel.posts.isEmpty)
    }

    private func makeViewModel(
        authRepository: AuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
        userRepository: UserRepository = MockUserRepository(),
        communityRepository: CommunityRepository = MockCommunityRepository(),
        connectionRepository: ConnectionRepository = MockConnectionRepository(),
        profilePostRepository: ProfilePostRepository = MockProfilePostRepository(),
        onProfileSaved: ((User) -> Void)? = nil,
        now: Date = Date()
    ) -> ProfileViewModel {
        ProfileViewModel(
            authRepository: authRepository,
            userRepository: userRepository,
            communityRepository: communityRepository,
            connectionRepository: connectionRepository,
            profilePostRepository: profilePostRepository,
            onProfileSaved: onProfileSaved,
            calendar: Self.calendar,
            timeZone: .gmt,
            now: { now }
        )
    }

    private func makeLoadedPostViewModel(
        text: String?,
        hasImage: Bool
    ) async -> (ProfileViewModel, MockProfilePostRepository, ProfilePost) {
        let posts = MockProfilePostRepository()
        let post = ProfilePost(
            id: "edit-post",
            authorId: MockAuthRepository.sampleUser.id,
            text: text,
            imageURL: hasImage ? URL(string: "https://example.com/original.jpg") : nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        posts.posts = [post]
        let viewModel = makeViewModel(profilePostRepository: posts)
        await viewModel.loadProfile()
        return (viewModel, posts, post)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private static func localDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private static func persistedDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        AgeCalculator.canonicalBirthDate(fromLocalDate: localDate(year, month, day), timeZone: .gmt)!
    }
}
