import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatOrderingMuteTests {
    @Test(
        "Muting any ordinary row preserves its visual position",
        arguments: ["first", "middle", "last"]
    )
    func mutingOrdinaryChatPreservesPosition(chatId: String) async {
        let repository = MockChatRepository()
        repository.visibleChats = ordinaryChats
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()
        let before = viewModel.unpinnedChats.map(\.id)

        await viewModel.setMuted(chatId: chatId, muted: true)

        #expect(viewModel.unpinnedChats.map(\.id) == before)
        #expect(viewModel.unpinnedChats.first { $0.id == chatId }?.isMuted == true)
    }

    @Test func unmutingOrdinaryChatPreservesPosition() async {
        let repository = MockChatRepository()
        repository.visibleChats = ordinaryChats.map { chat in
            var chat = chat
            chat.isMuted = chat.id == "middle"
            return chat
        }
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()
        let before = viewModel.unpinnedChats.map(\.id)

        await viewModel.setMuted(chatId: "middle", muted: false)

        #expect(viewModel.unpinnedChats.map(\.id) == before)
        #expect(viewModel.unpinnedChats.first { $0.id == "middle" }?.isMuted == false)
    }

    @Test func mutePersistsAcrossCanonicalReload() async {
        let repository = MockChatRepository()
        repository.visibleChats = ordinaryChats
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        await viewModel.setMuted(chatId: "middle", muted: true)
        await viewModel.loadChats(showLoading: false)

        #expect(viewModel.unpinnedChats.map(\.id) == ["first", "middle", "last"])
        #expect(viewModel.unpinnedChats.first { $0.id == "middle" }?.isMuted == true)
    }

    @Test func equalAndNilDatesUseStableIDTieBreaker() async {
        let repository = MockChatRepository()
        let equalDate = Date(timeIntervalSince1970: 100)
        repository.visibleChats = [
            chat(id: "dated-b", date: equalDate),
            chat(id: "nil-b", date: nil),
            chat(id: "dated-a", date: equalDate),
            chat(id: "nil-a", date: nil)
        ]
        let viewModel = makeViewModel(repository)

        await viewModel.loadChats()

        #expect(viewModel.unpinnedChats.map(\.id) == ["dated-a", "dated-b", "nil-a", "nil-b"])
    }

    @Test func muteDoesNotAffectPinnedManualOrder() async {
        let repository = MockChatRepository()
        repository.visibleChats = [
            chat(id: "pinned-second", date: .distantFuture, pinned: true, order: 1),
            chat(id: "pinned-first", date: .distantPast, pinned: true, order: 0),
            chat(id: "ordinary", date: Date())
        ]
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        await viewModel.setMuted(chatId: "pinned-first", muted: true)
        await viewModel.loadChats(showLoading: false)

        #expect(viewModel.pinnedChats.map(\.id) == ["pinned-first", "pinned-second"])
        #expect(viewModel.pinnedChats.first?.isMuted == true)
    }

    @Test func repositoryErrorRollsBackMuteWithoutChangingOrder() async {
        let repository = MockChatRepository()
        repository.visibleChats = ordinaryChats
        repository.setMutedError = TestError.failed
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()
        let before = viewModel.unpinnedChats

        await viewModel.setMuted(chatId: "middle", muted: true)

        #expect(viewModel.unpinnedChats == before)
        #expect(viewModel.actionErrorMessage != nil)
    }

    @Test func newerIncomingMessageLegitimatelyReordersOrdinaryChat() async throws {
        let repository = MockChatRepository()
        repository.visibleChats = ordinaryChats
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()

        let newestDate = Date(timeIntervalSince1970: 1_000)
        let index = try #require(repository.visibleChats.firstIndex { $0.id == "last" })
        repository.visibleChats[index].lastMessageAt = newestDate
        repository.visibleChats[index].lastMessageText = "New message"
        await viewModel.loadChats(showLoading: false)

        #expect(viewModel.unpinnedChats.map(\.id) == ["last", "first", "middle"])
    }

    @Test func failedRefreshPreservesLoadedChats() async {
        let repository = MockChatRepository()
        repository.visibleChats = ordinaryChats
        let viewModel = makeViewModel(repository)
        await viewModel.loadChats()
        let before = viewModel.unpinnedChats

        repository.fetchOrganizedChatsError = TestError.failed
        await viewModel.loadChats(showLoading: false)

        #expect(viewModel.unpinnedChats == before)
        #expect(viewModel.actionErrorMessage != nil)
    }

    private var ordinaryChats: [ChatSummary] {
        [
            chat(id: "last", date: Date(timeIntervalSince1970: 100)),
            chat(id: "first", date: Date(timeIntervalSince1970: 300)),
            chat(id: "middle", date: Date(timeIntervalSince1970: 200))
        ]
    }

    private func makeViewModel(_ repository: MockChatRepository) -> ChatsViewModel {
        ChatsViewModel(chatRepository: repository, currentUserId: "user-1")
    }

    private func chat(
        id: String,
        date: Date?,
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

    private enum TestError: Error {
        case failed
    }
}
