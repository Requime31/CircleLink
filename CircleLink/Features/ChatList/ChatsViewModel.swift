import Combine
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[ChatSummary]> = .idle
    @Published private(set) var hiddenChats: [ChatSummary] = []
    @Published private(set) var leaveErrorMessage: String?
    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var isPinMutationInFlight = false
    /// Bound to `.searchable` — filters the main (visible) list locally.
    @Published var searchText: String = ""

    private let chatRepository: ChatRepository
    private let currentUserId: String
    private static let previewMessageLimit = 5
    /// Bumps on every load start so stale fetches cannot overwrite newer optimistic state.
    private var loadGeneration = 0

    init(chatRepository: ChatRepository, currentUserId: String) {
        self.chatRepository = chatRepository
        self.currentUserId = currentUserId
    }

    var hiddenCount: Int { hiddenChats.count }

    private var hasLoadedContent: Bool {
        if case .loaded = state { return true }
        if case .empty = state { return true }
        return false
    }

    var pinnedChats: [ChatSummary] {
        filteredVisibleChats.filter(\.isPinned)
    }

    var unpinnedChats: [ChatSummary] {
        filteredVisibleChats.filter { !$0.isPinned }
    }

    /// Visible chats filtered by title / last message (case-insensitive).
    var filteredVisibleChats: [ChatSummary] {
        guard case let .loaded(chats) = state else { return [] }
        return Self.filter(chats, query: searchText)
    }

    func filteredHiddenChats(matching query: String) -> [ChatSummary] {
        Self.filter(hiddenChats, query: query)
    }

    func loadChats(showLoading: Bool = true) async {
        // A refresh that begins during an optimistic pin transaction could replace
        // the optimistic snapshot with pre-write server data. The next normal
        // refresh will pick up the persisted result.
        guard !isPinMutationInFlight else { return }
        loadGeneration += 1
        let generation = loadGeneration

        let preservesExistingState = hasLoadedContent
        if showLoading && !preservesExistingState {
            state = .loading
        }
        actionErrorMessage = nil

        do {
            let organized = try await chatRepository.fetchOrganizedChats()
            guard generation == loadGeneration else { return }
            hiddenChats = organized.hidden.map { chat in
                var chat = chat
                chat.isPinned = false
                chat.pinOrder = nil
                return chat
            }
            let visible = Self.sortedVisibleChats(organized.visible)
            // Empty visible + some hidden → still `.loaded` so the footer can show.
            if visible.isEmpty && organized.hidden.isEmpty {
                state = .empty
            } else {
                state = .loaded(visible)
            }
        } catch {
            guard generation == loadGeneration else { return }
            if preservesExistingState {
                actionErrorMessage = error.localizedDescription
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Last messages for context-menu peek (chronological, oldest → newest).
    func fetchConversationPreview(chatId: String) async -> [ChatMessageItem] {
        do {
            let fetched = try await chatRepository.fetchMessages(
                chatId: chatId,
                limit: Self.previewMessageLimit,
                before: nil
            )
            return fetched.map {
                ChatMessageItem(message: $0, currentUserId: currentUserId)
            }
        } catch {
            return []
        }
    }

    func setMuted(chatId: String, muted: Bool) async {
        actionErrorMessage = nil
        let stateSnapshot = state
        let hiddenSnapshot = hiddenChats
        applyLocalMute(chatId: chatId, muted: muted)
        // Invalidate in-flight list fetches so they cannot resurrect pre-mute rows.
        loadGeneration += 1

        do {
            try await chatRepository.setChatMuted(chatId: chatId, muted: muted)
        } catch {
            state = stateSnapshot
            hiddenChats = hiddenSnapshot
            actionErrorMessage = error.localizedDescription
        }
    }

    func setPinned(chatId: String, pinned: Bool) async {
        guard !isPinMutationInFlight, case let .loaded(chats) = state else { return }
        guard let index = chats.firstIndex(where: { $0.id == chatId }), chats[index].isPinned != pinned else {
            return
        }

        actionErrorMessage = nil
        isPinMutationInFlight = true
        let snapshot = chats
        var updated = chats
        updated[index].isPinned = pinned
        updated[index].pinOrder = pinned
            ? (updated.compactMap(\.pinOrder).max().map { $0 + 1 } ?? 0)
            : nil
        state = .loaded(Self.sortedVisibleChats(updated))
        loadGeneration += 1

        do {
            try await chatRepository.setChatPinned(chatId: chatId, pinned: pinned)
        } catch {
            state = .loaded(snapshot)
            actionErrorMessage = error.localizedDescription
        }
        isPinMutationInFlight = false
    }

    func reorderPinnedChats(chatIds: [String]) async {
        guard !isPinMutationInFlight, case let .loaded(chats) = state else { return }
        let currentIDs = Self.sortedVisibleChats(chats).filter(\.isPinned).map(\.id)
        guard chatIds != currentIDs,
              chatIds.count == currentIDs.count,
              Set(chatIds) == Set(currentIDs) else { return }

        actionErrorMessage = nil
        isPinMutationInFlight = true
        let snapshot = chats
        let ranks = Dictionary(uniqueKeysWithValues: chatIds.enumerated().map { ($0.element, $0.offset) })
        var updated = chats
        for index in updated.indices where updated[index].isPinned {
            updated[index].pinOrder = ranks[updated[index].id]
        }
        state = .loaded(Self.sortedVisibleChats(updated))
        loadGeneration += 1

        do {
            try await chatRepository.reorderPinnedChats(chatIds: chatIds)
        } catch {
            state = .loaded(snapshot)
            actionErrorMessage = error.localizedDescription
        }
        isPinMutationInFlight = false
    }

    func movePinnedChat(chatId: String, by offset: Int) async {
        var ids = pinnedChats.map(\.id)
        guard let source = ids.firstIndex(of: chatId) else { return }
        let destination = source + offset
        guard ids.indices.contains(destination) else { return }
        ids.swapAt(source, destination)
        await reorderPinnedChats(chatIds: ids)
    }

    func hideChat(chatId: String) async {
        actionErrorMessage = nil
        // Optimistic: drop from visible, bump into hidden bucket if we still have the row.
        if case var .loaded(chats) = state,
           let index = chats.firstIndex(where: { $0.id == chatId }) {
            var removed = chats.remove(at: index)
            removed.isPinned = false
            removed.pinOrder = nil
            if !hiddenChats.contains(where: { $0.id == chatId }) {
                hiddenChats.insert(removed, at: 0)
            }
            state = chats.isEmpty && hiddenChats.isEmpty ? .empty : .loaded(chats)
        }
        loadGeneration += 1

        do {
            try await chatRepository.hideChat(chatId: chatId)
        } catch {
            actionErrorMessage = error.localizedDescription
            await loadChats(showLoading: false)
        }
    }

    func unhideChat(chatId: String) async {
        actionErrorMessage = nil
        if let index = hiddenChats.firstIndex(where: { $0.id == chatId }) {
            let restored = hiddenChats.remove(at: index)
            if case var .loaded(chats) = state {
                if !chats.contains(where: { $0.id == chatId }) {
                    chats.append(restored)
                }
                state = .loaded(Self.sortedVisibleChats(chats))
            } else if case .empty = state {
                state = .loaded([restored])
            }
        }
        loadGeneration += 1

        do {
            try await chatRepository.unhideChat(chatId: chatId)
        } catch {
            actionErrorMessage = error.localizedDescription
            await loadChats(showLoading: false)
        }
    }

    /// Group leave from Chat Info. Does not leave the community.
    @discardableResult
    func leaveChat(chatId: String) async -> Bool {
        leaveErrorMessage = nil
        do {
            try await chatRepository.leaveChat(chatId: chatId)
            await loadChats()
            return true
        } catch {
            leaveErrorMessage = error.localizedDescription
            return false
        }
    }

    func clearLeaveError() {
        leaveErrorMessage = nil
    }

    func clearActionError() {
        actionErrorMessage = nil
    }

    func resetForm() {
        loadGeneration += 1
        state = .idle
        hiddenChats = []
        searchText = ""
        leaveErrorMessage = nil
        actionErrorMessage = nil
        isPinMutationInFlight = false
    }

    // MARK: - Private

    private func applyLocalMute(chatId: String, muted: Bool) {
        if case var .loaded(chats) = state,
           let index = chats.firstIndex(where: { $0.id == chatId }) {
            chats[index].isMuted = muted
            state = .loaded(chats)
        }
        if let index = hiddenChats.firstIndex(where: { $0.id == chatId }) {
            hiddenChats[index].isMuted = muted
        }
    }

    private static func filter(_ chats: [ChatSummary], query: String) -> [ChatSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return chats }
        return chats.filter { chat in
            chat.title.localizedCaseInsensitiveContains(trimmed)
                || (chat.lastMessageText?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private static func sortedVisibleChats(_ chats: [ChatSummary]) -> [ChatSummary] {
        chats.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.isPinned {
                let lhsOrder = lhs.pinOrder ?? Int.max
                let rhsOrder = rhs.pinOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            } else if lhs.lastMessageAt != rhs.lastMessageAt {
                switch (lhs.lastMessageAt, rhs.lastMessageAt) {
                case let (lhsDate?, rhsDate?): return lhsDate > rhsDate
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): break
                }
            }
            return lhs.id < rhs.id
        }
    }
}
