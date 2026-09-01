import Foundation
import Testing
import UIKit
@testable import CircleLink

@MainActor
struct CommunityDetailViewModelTests {
    private func makeViewModel(
        community: MockCommunityRepository = MockCommunityRepository(),
        chat: MockChatRepository = MockChatRepository(),
        auth: MockAuthRepository = MockAuthRepository(currentUser: MockAuthRepository.sampleUser),
        posts: CommunityPostRepository? = nil,
        images: CommunityImageStorage? = nil
    ) -> (CommunityDetailViewModel, MockCommunityRepository, MockChatRepository) {
        let viewModel = CommunityDetailViewModel(
            communityId: "community-1",
            communityRepository: community,
            chatRepository: chat,
            authRepository: auth,
            communityPostRepository: posts ?? StubCommunityPostRepository(),
            communityImageStorage: images ?? StubCommunityImageStorage(),
            userRepository: MockUserRepository()
        )
        return (viewModel, community, chat)
    }

    @Test func loadSetsCommunityMembersAndMembership() async {
        let (viewModel, _, _) = makeViewModel()

        await viewModel.load()

        #expect(viewModel.isMember == true)
        if case let .loaded(community) = viewModel.communityState {
            #expect(community.id == "community-1")
        } else {
            Issue.record("Expected loaded community")
        }
        if case let .loaded(members) = viewModel.membersState {
            #expect(members.contains { $0.id == "user-1" })
        } else {
            Issue.record("Expected loaded members")
        }
    }

    @Test func joinCallsRepositoryAndRefreshesMembership() async {
        let community = MockCommunityRepository()
        community.membersByCommunity["community-1"] = []
        let (viewModel, repo, _) = makeViewModel(community: community)

        await viewModel.load()
        #expect(viewModel.isMember == false)

        await viewModel.join()

        #expect(repo.joinCallCount == 1)
        #expect(repo.lastJoinedCommunityId == "community-1")
        #expect(viewModel.isMember == true)
    }

    @Test func leaveCallsLeaveGroupChatThenCommunityLeave() async {
        let callLog = MockCallLog()
        let community = MockCommunityRepository()
        community.callLog = callLog
        let chat = MockChatRepository()
        chat.callLog = callLog
        let (viewModel, _, _) = makeViewModel(community: community, chat: chat)
        await viewModel.load()
        #expect(viewModel.isMember == true)

        await viewModel.leave()

        #expect(chat.leaveGroupChatCallCount == 1)
        #expect(chat.lastLeaveGroupCommunityId == "community-1")
        #expect(community.leaveCallCount == 1)
        #expect(community.lastLeftCommunityId == "community-1")
        #expect(callLog.entries == ["leaveGroupChat", "community.leave"])
        #expect(viewModel.isMember == false)
    }

    @Test func leaveStopsWhenLeaveGroupChatFails() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Cannot leave chat" }
        }

        let chat = MockChatRepository()
        chat.leaveGroupChatError = Boom()
        let (viewModel, community, _) = makeViewModel(chat: chat)
        await viewModel.load()

        await viewModel.leave()

        #expect(chat.leaveGroupChatCallCount == 1)
        #expect(community.leaveCallCount == 0)
        #expect(viewModel.membershipErrorMessage == "Cannot leave chat")
        #expect(viewModel.isMember == true)
    }

    @Test func openGroupChatRequiresMembership() async {
        let community = MockCommunityRepository()
        community.membersByCommunity["community-1"] = []
        let (viewModel, _, chat) = makeViewModel(community: community)
        await viewModel.load()

        let result = await viewModel.openGroupChat()

        #expect(result == nil)
        #expect(chat.createGroupChatCallCount == 0)
        #expect(viewModel.membershipErrorMessage == "Join this community to open group chat.")
    }

    @Test func openGroupChatCreatesChatForMember() async {
        let chat = MockChatRepository()
        chat.createGroupChatResult = "group_community-1"
        let (viewModel, _, _) = makeViewModel(chat: chat)
        await viewModel.load()

        let result = await viewModel.openGroupChat()

        #expect(chat.createGroupChatCallCount == 1)
        #expect(result?.chatId == "group_community-1")
        #expect(result?.title == "Swift Devs")
    }

    @Test func postUpdateKeepsExistingImageWhenUnchanged() async {
        let (viewModel, posts, post) = await makeLoadedPostViewModel(text: "Same", hasImage: true)

        let ok = await viewModel.updatePost(post, text: "Same", image: nil, removeImage: false)

        #expect(ok)
        #expect(posts.lastUpdateImage == nil)
        #expect(!posts.lastUpdateRemoveImage)
        #expect(viewModel.posts.first?.imageURL == post.imageURL)
    }

    @Test func postUpdateSupportsTextReplaceAndRemove() async {
        let (viewModel, posts, post) = await makeLoadedPostViewModel(text: "Old", hasImage: true)
        let replacement = Data([7, 8, 9])

        #expect(await viewModel.updatePost(post, text: "New", image: replacement, removeImage: false))
        #expect(posts.lastUpdateImage == replacement)
        guard let replaced = viewModel.posts.first else {
            Issue.record("Expected updated post")
            return
        }
        #expect(await viewModel.updatePost(replaced, text: "New", image: nil, removeImage: true))
        #expect(posts.lastUpdateRemoveImage)
        #expect(viewModel.posts.first?.text == "New")
        #expect(viewModel.posts.first?.imageURL == nil)
    }

    @Test func emptyPostAndRepositoryErrorsKeepOriginalPost() async {
        let (viewModel, posts, post) = await makeLoadedPostViewModel(text: nil, hasImage: true)

        let emptyUpdate = await viewModel.updatePost(post, text: " ", image: nil, removeImage: true)
        #expect(!emptyUpdate)
        #expect(viewModel.posts.first == post)
        posts.updateError = TestPostError.failed
        let failedUpdate = await viewModel.updatePost(post, text: "Changed", image: nil, removeImage: false)
        #expect(!failedUpdate)
        #expect(viewModel.postErrorMessage != nil)
        #expect(viewModel.posts.first == post)
    }

    @Test func duplicatePostUpdateIsIgnored() async {
        let (viewModel, posts, post) = await makeLoadedPostViewModel(text: "Old", hasImage: false)
        posts.shouldSuspendUpdate = true

        let first = Task { await viewModel.updatePost(post, text: "First", image: nil, removeImage: false) }
        while !posts.hasPendingUpdate { await Task.yield() }
        let duplicate = await viewModel.updatePost(post, text: "Second", image: nil, removeImage: false)
        posts.resumeUpdate()

        #expect(!duplicate)
        #expect(await first.value)
        #expect(posts.updateCallCount == 1)
    }

    @Test func ownerCanSaveCommunityMetadataWithUnchangedCover() async {
        let repo = ownerCommunityRepository()
        let (viewModel, _, _) = makeViewModel(community: repo)
        await viewModel.load()

        let saved = await viewModel.saveCommunity(
            name: "  Renamed  ", description: " Updated ", coverEdit: .unchanged
        )

        #expect(saved)
        #expect(repo.updateMetadataCallCount == 1)
        #expect(repo.communities.first?.name == "Renamed")
        #expect(repo.communities.first?.description == "Updated")
    }

    @Test func ownerCanReplaceAndRemoveCommunityCover() async {
        let repo = ownerCommunityRepository(hasCover: true)
        let images = MockCommunityImageStorage()
        let (viewModel, _, _) = makeViewModel(community: repo, images: images)
        await viewModel.load()

        #expect(await viewModel.saveCommunity(name: "Swift Devs", description: "iOS chat", coverEdit: .replace(validImageData)))
        #expect(images.uploadCoverCallCount == 1)
        #expect(repo.communities.first?.coverImageURL != nil)
        #expect(await viewModel.saveCommunity(name: "Swift Devs", description: "iOS chat", coverEdit: .remove))
        #expect(images.deleteCoverCallCount == 1)
        #expect(repo.communities.first?.coverImageURL == nil)
    }

    private var validImageData: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    @Test func metadataFailureStopsCoverAndImageFailureKeepsSavedMetadata() async {
        let repo = ownerCommunityRepository()
        let images = MockCommunityImageStorage()
        let (viewModel, _, _) = makeViewModel(community: repo, images: images)
        await viewModel.load()

        repo.updateMetadataError = TestPostError.failed
        let metadataFailure = await viewModel.saveCommunity(
            name: "New", description: "", coverEdit: .replace(validImageData)
        )
        #expect(!metadataFailure)
        #expect(images.uploadCoverCallCount == 0)

        repo.updateMetadataError = nil
        images.uploadCoverError = TestPostError.failed
        let imageFailure = await viewModel.saveCommunity(
            name: "New", description: "Saved", coverEdit: .replace(validImageData)
        )
        #expect(!imageFailure)
        #expect(repo.communities.first?.name == "New")
        #expect(viewModel.communityEditErrorMessage?.contains("Name and description were saved") == true)
    }

    @Test func duplicateCommunitySaveAndNonOwnerAreRejected() async {
        let repo = ownerCommunityRepository()
        let images = MockCommunityImageStorage()
        images.shouldSuspendUpload = true
        let (viewModel, _, _) = makeViewModel(community: repo, images: images)
        await viewModel.load()

        let first = Task {
            await viewModel.saveCommunity(name: "First", description: "", coverEdit: .replace(validImageData))
        }
        while !images.hasPendingUpload { await Task.yield() }
        let duplicate = await viewModel.saveCommunity(name: "Second", description: "", coverEdit: .unchanged)
        images.resumeUpload()
        #expect(!duplicate)
        #expect(await first.value)
        #expect(repo.updateMetadataCallCount == 1)

        let outsider = MockAuthRepository(currentUser: User(id: "outsider", displayName: "Outsider"))
        let (nonOwnerViewModel, _, _) = makeViewModel(community: repo, auth: outsider)
        await nonOwnerViewModel.load()
        let unauthorized = await nonOwnerViewModel.saveCommunity(
            name: "Nope", description: "", coverEdit: .unchanged
        )
        #expect(!unauthorized)
        #expect(nonOwnerViewModel.communityEditErrorMessage?.contains("owner") == true)
    }

    private func makeLoadedPostViewModel(
        text: String?,
        hasImage: Bool
    ) async -> (CommunityDetailViewModel, MockCommunityPostRepository, CommunityPost) {
        let posts = MockCommunityPostRepository()
        let post = CommunityPost(
            id: "edit-post",
            communityId: "community-1",
            authorId: MockAuthRepository.sampleUser.id,
            text: text,
            imageURL: hasImage ? URL(string: "https://example.com/original.jpg") : nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        posts.posts = [post]
        let (viewModel, _, _) = makeViewModel(posts: posts)
        await viewModel.load()
        return (viewModel, posts, post)
    }

    private func ownerCommunityRepository(hasCover: Bool = false) -> MockCommunityRepository {
        let repo = MockCommunityRepository()
        repo.communities = [
            Community(
                id: "community-1", name: "Swift Devs", description: "iOS chat",
                interestTag: "Swift", memberCount: 1,
                coverImageURL: hasCover ? URL(string: "https://example.com/original.jpg") : nil,
                creatorId: MockAuthRepository.sampleUser.id
            )
        ]
        return repo
    }
}

private enum TestPostError: Error { case failed }

private final class MockCommunityPostRepository: CommunityPostRepository, @unchecked Sendable {
    var posts: [CommunityPost] = []
    var updateCallCount = 0
    var updateError: Error?
    var lastUpdateImage: Data?
    var lastUpdateRemoveImage = false
    var shouldSuspendUpdate = false
    private var updateContinuation: CheckedContinuation<Void, Never>?
    var hasPendingUpdate: Bool { updateContinuation != nil }

    func fetchPosts(communityId: String, limit: Int, before: Date?) async throws -> [CommunityPost] {
        Array(posts.filter { $0.communityId == communityId }.prefix(limit))
    }

    func createPost(communityId: String, postId: String, text: String?, image: Data?) async throws -> CommunityPost {
        CommunityPost(id: postId, communityId: communityId, authorId: MockAuthRepository.sampleUser.id,
                      text: text, imageURL: nil, createdAt: Date())
    }

    func updatePost(
        _ post: CommunityPost,
        text: String?,
        image: Data?,
        removeImage: Bool
    ) async throws -> CommunityPost {
        updateCallCount += 1
        lastUpdateImage = image
        lastUpdateRemoveImage = removeImage
        if shouldSuspendUpdate {
            await withCheckedContinuation { updateContinuation = $0 }
        }
        if let updateError { throw updateError }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let validText = !(trimmed?.isEmpty ?? true)
        var imageURL = post.imageURL
        if image != nil { imageURL = URL(string: "https://example.com/replacement.jpg") }
        else if removeImage { imageURL = nil }
        guard validText || imageURL != nil else { throw TestPostError.failed }

        let updated = CommunityPost(id: post.id, communityId: post.communityId, authorId: post.authorId,
                                    text: validText ? trimmed : nil, imageURL: imageURL, createdAt: post.createdAt)
        if let index = posts.firstIndex(where: { $0.id == post.id }) { posts[index] = updated }
        return updated
    }

    func deletePost(_ post: CommunityPost) async throws {
        posts.removeAll { $0.id == post.id }
    }

    func resumeUpdate() {
        updateContinuation?.resume()
        updateContinuation = nil
    }
}
