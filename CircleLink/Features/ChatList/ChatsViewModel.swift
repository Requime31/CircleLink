import Combine
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[ChatSummary]> = .idle
    @Published private(set) var hiddenChats: [ChatSummary] = []
    @Published private(set) var leaveErrorMessage: String?
    @Published private(set) var actionErrorMessage: String?
    /// Bound to `.searchable` — filters the main (visible) list locally.
    @Published var searchText: String = ""

    private let chatRepository: ChatRepository
    private let currentUserId: String
    private static let previewMessageLimit = 12
    /// Bumps on every load start so stale fetches cannot overwrite newer optimistic state.
    private var loadGeneration = 0

    init(chatRepository: ChatRepository, currentUserId: String) {
        self.chatRepository = chatRepository
        self.currentUserId = currentUserId
    }

    var hiddenCount: Int { hiddenChats.count }

    /// Visible chats filtered by title / last message (case-insensitive).
    var filteredVisibleChats: [ChatSummary] {
        guard case let .loaded(chats) = state else { return [] }
        return Self.filter(chats, query: searchText)
    }

    func filteredHiddenChats(matching query: String) -> [ChatSummary] {
        Self.filter(hiddenChats, query: query)
    }

    func loadChats(showLoading: Bool = true) async {
        loadGeneration += 1
        let generation = loadGeneration

        if showLoading {
            state = .loading
        }

        do {
            let organized = try await chatRepository.fetchOrganizedChats()
            guard generation == loadGeneration else { return }
            hiddenChats = organized.hidden
            // Empty visible + some hidden → still `.loaded` so the footer can show.
            if organized.visible.isEmpty && organized.hidden.isEmpty {
                state = .empty
            } else {
                state = .loaded(organized.visible)
            }
        } catch {
            guard generation == loadGeneration else { return }
            state = .error(error.localizedDescription)
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
        applyLocalMute(chatId: chatId, muted: muted)
        // Invalidate in-flight list fetches so they cannot resurrect pre-mute rows.
        loadGeneration += 1

        do {
            try await chatRepository.setChatMuted(chatId: chatId, muted: muted)
        } catch {
            actionErrorMessage = error.localizedDescription
            await loadChats(showLoading: false)
        }
    }

    func hideChat(chatId: String) async {
        actionErrorMessage = nil
        // Optimistic: drop from visible, bump into hidden bucket if we still have the row.
        if case var .loaded(chats) = state,
           let index = chats.firstIndex(where: { $0.id == chatId }) {
            let removed = chats.remove(at: index)
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
                    chats.insert(restored, at: 0)
                }
                state = .loaded(chats)
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
        state = .idle
        hiddenChats = []
        searchText = ""
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
}
