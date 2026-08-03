import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatsViewModelTests {
    private func makeSummary(
        id: String,
        title: String,
        lastMessageText: String? = nil,
        isMuted: Bool = false,
        communityId: String? = nil
    ) -> ChatSummary {
        ChatSummary(
            id: id,
            type: communityId == nil ? .direct : .group,
            title: title,
            lastMessageText: lastMessageText,
            lastMessageAt: Date(),
            unreadCount: 0,
            avatarURL: nil,
            avatarBase64: nil,
            communityId: communityId,
            peerUserId: communityId == nil ? "peer-1" : nil,
            isMuted: isMuted
        )
    }

    @Test func loadChatsSetsVisibleAndHidden() async {
        let repo = MockChatRepository()
        repo.visibleChats = [makeSummary(id: "c1", title: "Alice")]
        repo.hiddenChats = [makeSummary(id: "c2", title: "Bob")]
        let viewModel = ChatsViewModel(chatRepository: repo, currentUserId: "user-1")

        await viewModel.loadChats()

        if case let .loaded(chats) = viewModel.state {
            #expect(chats.map(\.id) == ["c1"])
        } else {
            Issue.record("Expected loaded visible chats")
        }
        #expect(viewModel.hiddenChats.map(\.id) == ["c2"])
        #expect(viewModel.hiddenCount == 1)
    }

    @Test func staleLoadDoesNotOverwriteNewerOptimisticMute() async {
        let repo = MockChatRepository()
        let unmuted = makeSummary(id: "c1", title: "Alice", isMuted: false)
        repo.visibleChats = [unmuted]
        let viewModel = ChatsViewModel(chatRepository: repo, currentUserId: "user-1")

        await viewModel.loadChats()

        repo.fetchOrganizedResultOverride = OrganizedChats(visible: [unmuted], hidden: [])
        repo.shouldHoldFetchOrganized = true
        let refreshTask = Task { await viewModel.loadChats(showLoading: false) }
        await waitUntil { repo.isHoldingFetchOrganized }

        await viewModel.setMuted(chatId: "c1", muted: true)
        repo.releaseFetchOrganizedHold()
        await refreshTask.value

        if case let .loaded(chats) = viewModel.state {
            #expect(chats.first?.isMuted == true)
        } else {
            Issue.record("Expected muted chat to survive stale load")
        }
    }

    @Test func overlappingReloadCancelsPreviousFetch() async {
        let repo = MockChatRepository()
        repo.visibleChats = [makeSummary(id: "old", title: "Old")]
        let viewModel = ChatsViewModel(chatRepository: repo, currentUserId: "user-1")

        repo.shouldHoldFetchOrganized = true
        let first = Task { await viewModel.loadChats() }
        await waitUntil { repo.isHoldingFetchOrganized }

        repo.shouldHoldFetchOrganized = false
        repo.visibleChats = [makeSummary(id: "new", title: "New")]
        let second = Task { await viewModel.loadChats() }
        // First hold still open — release after second started so first becomes stale.
        await Task.yield()
        repo.releaseFetchOrganizedHold()
        await first.value
        await second.value

        if case let .loaded(chats) = viewModel.state {
            #expect(chats.map(\.id) == ["new"])
        } else {
            Issue.record("Expected latest reload result")
        }
    }

    @Test func leaveChatIgnoresDuplicateWhileInFlight() async {
        let repo = MockChatRepository()
        repo.visibleChats = [makeSummary(id: "c1", title: "Group", communityId: "community-1")]
        // Reuse organized hold via leave → loadChats; hold leave by holding organized after leave mutates.
        let viewModel = ChatsViewModel(chatRepository: repo, currentUserId: "user-1")
        await viewModel.loadChats()

        // First leave succeeds immediately; second should be ignored by isLeaving.
        // Hold the post-leave reload so isLeaving stays true.
        repo.shouldHoldFetchOrganized = true
        let first = Task { await viewModel.leaveChat(chatId: "c1") }
        await waitUntil { viewModel.isLeaving || repo.leaveChatCallCount == 1 }
        let second = await viewModel.leaveChat(chatId: "c1")
        #expect(second == false)
        #expect(repo.leaveChatCallCount == 1)

        repo.releaseFetchOrganizedHold()
        let firstResult = await first.value
        #expect(firstResult == true)
        #expect(!viewModel.isLeaving)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
    }
}
