import Foundation
import Testing
@testable import CircleLink

@MainActor
struct ChatPinningDataTests {
    @Test func mapperUsesBackwardCompatibleLegacyDefaults() {
        let legacy = FirestoreChatMapper.pinMetadata(from: [:])
        #expect(!legacy.isPinned)
        #expect(legacy.pinOrder == nil)

        let pinned = FirestoreChatMapper.pinMetadata(
            from: ["pinned": true, "pinOrder": 3]
        )
        #expect(pinned.isPinned)
        #expect(pinned.pinOrder == 3)

        let staleHidden = FirestoreChatMapper.pinMetadata(
            from: ["hidden": true, "pinned": true, "pinOrder": 1]
        )
        #expect(!staleHidden.isPinned)
        #expect(staleHidden.pinOrder == nil)
    }

    @Test func pinAndUnpinAreIdempotentAndPersistAcrossFetch() async throws {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a")]

        try await repository.setChatPinned(chatId: "a", pinned: true)
        let initialRank = repository.visibleChats[0].pinOrder
        try await repository.setChatPinned(chatId: "a", pinned: true)

        #expect(repository.visibleChats[0].isPinned)
        #expect(repository.visibleChats[0].pinOrder == initialRank)
        #expect((try await repository.fetchOrganizedChats()).visible[0].isPinned)

        try await repository.setChatPinned(chatId: "a", pinned: false)
        try await repository.setChatPinned(chatId: "a", pinned: false)
        #expect(!repository.visibleChats[0].isPinned)
        #expect(repository.visibleChats[0].pinOrder == nil)
    }

    @Test func reorderStoresStableIncreasingRanks() async throws {
        let repository = MockChatRepository()
        repository.visibleChats = [
            chat(id: "a", pinned: true, order: 0),
            chat(id: "b", pinned: true, order: 1),
            chat(id: "ordinary")
        ]

        try await repository.reorderPinnedChats(chatIds: ["b", "a"])

        #expect(repository.visibleChats.first { $0.id == "b" }?.pinOrder == 0)
        #expect(repository.visibleChats.first { $0.id == "a" }?.pinOrder == 1)
        #expect(repository.visibleChats.first { $0.id == "ordinary" }?.pinOrder == nil)
    }

    @Test func reorderRejectsDuplicateUnknownHiddenForeignAndIncompleteSets() async {
        let repository = MockChatRepository()
        repository.visibleChats = [
            chat(id: "a", pinned: true, order: 0),
            chat(id: "b", pinned: true, order: 1),
            chat(id: "foreign", pinned: true, order: 2)
        ]
        repository.hiddenChats = [chat(id: "hidden")]
        repository.foreignChatIds = ["foreign"]

        await expect(.duplicateChatIDs) {
            try await repository.reorderPinnedChats(chatIds: ["a", "a"])
        }
        await expect(.unknownChat("missing")) {
            try await repository.reorderPinnedChats(chatIds: ["missing"])
        }
        await expect(.hiddenChat("hidden")) {
            try await repository.reorderPinnedChats(chatIds: ["hidden"])
        }
        await expect(.incompletePinnedSet) {
            try await repository.reorderPinnedChats(chatIds: ["a"])
        }
        await expect(.notParticipant("foreign")) {
            try await repository.reorderPinnedChats(chatIds: ["a", "b", "foreign"])
        }
    }

    @Test func hideClearsPinMetadataAndMovesChatOutOfVisibleSet() async throws {
        let repository = MockChatRepository()
        repository.visibleChats = [chat(id: "a", pinned: true, order: 0)]

        try await repository.hideChat(chatId: "a")

        #expect(repository.visibleChats.isEmpty)
        #expect(repository.hiddenChats.count == 1)
        #expect(repository.hiddenChats[0].isPinned == false)
        #expect(repository.hiddenChats[0].pinOrder == nil)
    }

    @Test func failedBatchLeavesEveryRankUnchanged() async {
        let repository = MockChatRepository()
        repository.visibleChats = [
            chat(id: "a", pinned: true, order: 0),
            chat(id: "b", pinned: true, order: 1)
        ]
        let before = repository.visibleChats
        repository.reorderPinnedError = NSError(domain: "test", code: 1)

        do {
            try await repository.reorderPinnedChats(chatIds: ["b", "a"])
            Issue.record("Expected batch failure")
        } catch {
            #expect(repository.visibleChats == before)
        }
    }

    @Test func liveRepositoryRequiresCurrentUserBeforeAccessingFirestore() async {
        let repository = FirestoreChatRepository(
            imageStorage: StubChatImageStorage(),
            currentUserID: { nil }
        )

        do {
            try await repository.setChatPinned(chatId: "chat-1", pinned: true)
            Issue.record("Expected notAuthenticated")
        } catch let error as FirestoreChatError {
            guard case .notAuthenticated = error else {
                Issue.record("Expected notAuthenticated, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func chat(
        id: String,
        pinned: Bool = false,
        order: Int? = nil
    ) -> ChatSummary {
        ChatSummary(
            id: id,
            type: .direct,
            title: id,
            lastMessageText: nil,
            lastMessageAt: nil,
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

    private func expect(
        _ expected: ChatPinningError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected)")
        } catch let error as ChatPinningError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
