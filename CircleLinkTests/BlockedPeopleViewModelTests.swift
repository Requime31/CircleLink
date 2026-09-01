import Foundation
import Testing
@testable import CircleLink

@MainActor
struct BlockedPeopleViewModelTests {
    @Test func emptyRepositoryProducesEmptyState() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test func loadResolvesProfilesInDeterministicNameOrder() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["z", "a"]
        let users = MockUserRepository()
        users.profiles = [
            "z": User(id: "z", displayName: "Zoe"),
            "a": User(id: "a", displayName: "alex")
        ]
        let viewModel = makeViewModel(moderation: moderation, users: users)

        await viewModel.load()

        #expect(loadedRows(viewModel).map(\.displayName) == ["alex", "Zoe"])
    }

    @Test func loadFailureCanRetry() async {
        let moderation = MockModerationRepository()
        moderation.fetchBlockedError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Offline"])
        let viewModel = makeViewModel(moderation: moderation)

        await viewModel.load()
        #expect(viewModel.state == .error("Offline"))

        moderation.fetchBlockedError = nil
        await viewModel.load()
        #expect(viewModel.state == .empty)
    }

    @Test func missingAndDeactivatedProfilesUseSafeFallbackRows() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["missing", "deactivated"]
        let users = MockUserRepository()
        users.profiles = [
            "deactivated": User(
                id: "deactivated",
                displayName: "Private Name",
                accountState: .deactivated
            )
        ]
        let viewModel = makeViewModel(moderation: moderation, users: users)

        await viewModel.load()

        let rows = loadedRows(viewModel)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.isFallback })
        #expect(rows.allSatisfy { $0.displayName == "Unavailable account" })
        #expect(rows.allSatisfy { $0.avatarURL == nil && $0.avatarBase64 == nil })
    }

    @Test func successfulUnblockOptimisticallyRemovesRow() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["peer-1"]
        let viewModel = makeViewModel(moderation: moderation)
        await viewModel.load()
        let row = try! #require(loadedRows(viewModel).first)

        #expect(await viewModel.unblock(row))
        #expect(viewModel.state == .empty)
        #expect(!moderation.blockedUserIds.contains(row.id))
    }

    @Test func failedUnblockRollsBackAtOriginalPosition() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["peer-1"]
        moderation.unblockError = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Try again"])
        let viewModel = makeViewModel(moderation: moderation)
        await viewModel.load()
        let row = try! #require(loadedRows(viewModel).first)

        #expect(await viewModel.unblock(row) == false)
        #expect(loadedRows(viewModel) == [row])
        #expect(viewModel.actionErrorMessage == "Try again")
    }

    @Test func concurrentTapForSameRowCallsRepositoryOnce() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["peer-1"]
        moderation.shouldSuspendUnblock = true
        let viewModel = makeViewModel(moderation: moderation)
        await viewModel.load()
        let row = try! #require(loadedRows(viewModel).first)

        let first = Task { await viewModel.unblock(row) }
        await Task.yield()
        #expect(await viewModel.unblock(row) == false)
        #expect(moderation.unblockCallCount == 1)
        moderation.resumeUnblock()
        #expect(await first.value)
    }

    @Test func cancelledLoadDoesNotPublishLateProfiles() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["peer-1"]
        moderation.shouldSuspendBlockedFetch = true
        let viewModel = makeViewModel(moderation: moderation)

        let loadTask = Task { await viewModel.load() }
        for _ in 0..<100 where !moderation.hasPendingBlockedFetch { await Task.yield() }
        loadTask.cancel()
        moderation.resumeBlockedFetch()
        await loadTask.value

        #expect(viewModel.state == .loading)
    }

    @Test func sessionResetIgnoresLateUnblockResult() async {
        let moderation = MockModerationRepository()
        moderation.blockedUserIds = ["peer-1"]
        moderation.shouldSuspendUnblock = true
        let viewModel = makeViewModel(moderation: moderation)
        await viewModel.load()
        let row = try! #require(loadedRows(viewModel).first)

        let unblockTask = Task { await viewModel.unblock(row) }
        await Task.yield()
        viewModel.reset()
        moderation.resumeUnblock()

        #expect(await unblockTask.value == false)
        #expect(viewModel.state == .idle)
        #expect(viewModel.actionErrorMessage == nil)
    }

    private func makeViewModel(
        moderation: MockModerationRepository = MockModerationRepository(),
        users: MockUserRepository = MockUserRepository()
    ) -> BlockedPeopleViewModel {
        BlockedPeopleViewModel(
            moderationRepository: moderation,
            userRepository: users
        )
    }

    private func loadedRows(_ viewModel: BlockedPeopleViewModel) -> [BlockedPersonRow] {
        guard case let .loaded(rows) = viewModel.state else { return [] }
        return rows
    }
}
