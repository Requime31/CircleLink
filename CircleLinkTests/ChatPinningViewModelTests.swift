import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatPinningViewModelTests {
    @Test func splitsAndSortsPinnedAndOrdinaryChatsDeterministically() async {
        let repository = MockChatRepository()
        let date = Date(timeIntervalSince1970: 1_000)
        repository.visibleChats = [
            chat(id: "ordinary-b", date: date),
            chat(id: "pinned-b", pinned: true, order: 1),
            chat(id: "ordinary-a", date: date),
            chat(id: "pinned-a", pinned: true, order: 1),
            chat(id: "newest", date: date.addingTimeInterval(10))
        ]
        let viewModel = makeViewModel(repository)

        await viewModel.loadChats()

        #expect(viewModel.pinnedChats.map(\.id) == ["pinned-a", "pinned-b"])
        #expect(viewModel.unpinnedChats.map(\.id) == ["newest", "ordinary-a", "ordinary-b"])
        #expect(Set(viewModel.pinnedChats.map(\.id)).isDisjoint(with: viewModel.unpinnedChats.map(\.id)))
    }

    @Test func hiddenChatsAreExcludedEvenWithStalePinMetadata() async {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "visible")]
        repository.hiddenChats = [chat(id: "hidden", pinned: true, order: 0)]
        let viewModel = makeViewModel(repository)

        await viewModel.loadChats()

        #expect(viewModel.pinnedChats.isEmpty)
        #expect(viewModel.hiddenChats.first?.isPinned == false)
        #expect(viewModel.hiddenChats.first?.pinOrder == nil)
    }

    @Test func pinIsOptimisticAndFailureRollsBack() async {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a")]
        repository.shouldSuspendPinMutation = true
        repository.setPinnedError = TestError.failed
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        let operation = Task { await viewModel.setPinned(chatId: "a", pinned: true) }
        await waitUntil { repository.hasPendingPinMutation }

        #expect(viewModel.pinnedChats.map(\.id) == ["a"])
        #expect(viewModel.isPinMutationInFlight)

        repository.resumePinMutation()
        await operation.value

        #expect(viewModel.pinnedChats.isEmpty)
        #expect(viewModel.actionErrorMessage != nil)
        #expect(!viewModel.isPinMutationInFlight)
    }

    @Test func unpinIsOptimisticAndPersists() async {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a", pinned: true, order: 0)]
        repository.shouldSuspendPinMutation = true
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        let operation = Task { await viewModel.setPinned(chatId: "a", pinned: false) }
        await waitUntil { repository.hasPendingPinMutation }
        #expect(viewModel.pinnedChats.isEmpty)

        repository.resumePinMutation()
        await operation.value
        await viewModel.loadChats(showLoading: false)

        #expect(viewModel.pinnedChats.isEmpty)
        #expect(repository.pinnedRequests.count == 1)
        #expect(repository.pinnedRequests.first?.pinned == false)
    }

    @Test func reorderPersistsAndFailureRollsBack() async {
        let repository = MockChatRepository()
        repository.visibleChats = [
            chat(id: "a", pinned: true, order: 0),
            chat(id: "b", pinned: true, order: 1)
        ]
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        await viewModel.reorderPinnedChats(chatIds: ["b", "a"])
        await viewModel.loadChats(showLoading: false)
        #expect(viewModel.pinnedChats.map(\.id) == ["b", "a"])
        #expect(repository.reorderedPinnedChatIds.last == ["b", "a"])

        repository.reorderPinnedError = TestError.failed
        await viewModel.reorderPinnedChats(chatIds: ["a", "b"])
        #expect(viewModel.pinnedChats.map(\.id) == ["b", "a"])
        #expect(viewModel.actionErrorMessage != nil)
    }

    @Test func staleRefreshCannotOverwritePinMutation() async {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a")]
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        repository.shouldSuspendOrganizedFetch = true
        let staleRefresh = Task { await viewModel.loadChats(showLoading: false) }
        await waitUntil { repository.hasPendingOrganizedFetch }

        await viewModel.setPinned(chatId: "a", pinned: true)
        repository.resumeOrganizedFetch()
        await staleRefresh.value

        #expect(viewModel.pinnedChats.map(\.id) == ["a"])
    }

    @Test func overlappingPinOperationsAreIgnored() async {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a"), chat(id: "b")]
        repository.shouldSuspendPinMutation = true
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        let first = Task { await viewModel.setPinned(chatId: "a", pinned: true) }
        await waitUntil { repository.hasPendingPinMutation }
        await viewModel.setPinned(chatId: "b", pinned: true)

        #expect(repository.setPinnedCallCount == 1)
        #expect(viewModel.pinnedChats.map(\.id) == ["a"])
        repository.resumePinMutation()
        await first.value
    }

    @Test func refreshStartedDuringPinMutationDoesNotReplaceOptimisticState() async {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a")]
        repository.shouldSuspendPinMutation = true
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        let pin = Task { await viewModel.setPinned(chatId: "a", pinned: true) }
        await waitUntil { repository.hasPendingPinMutation }
        await viewModel.loadChats(showLoading: false)

        #expect(viewModel.pinnedChats.map(\.id) == ["a"])
        repository.resumePinMutation()
        await pin.value
    }

    private func makeViewModel(_ repository: MockChatRepository) -> ChatsViewModel {
        ChatsViewModel(chatRepository: repository, currentUserId: "user-1")
    }

    private func chat(
        id: String,
        date: Date? = nil,
        pinned: Bool = false,
        order: Int? = nil
    ) -> ChatSummary {
        ChatSummary(
            id: id,
            type: .direct,
            title: id,
            lastMessageText: nil,
            lastMessageAt: date,
            unreadCount: 0,
            avatarURL: nil,
            avatarBase64: nil,
            communityId: nil,
            peerUserId: "peer",
            isMuted: false,
            isPinned: pinned,
            pinOrder: order
        )
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }

    private enum TestError: Error {
        case failed
    }
}
