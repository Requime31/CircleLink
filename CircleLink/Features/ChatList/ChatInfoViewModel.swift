import Combine
import Foundation

/// Loads Chat Info and owns mute / leave / hide / delete / clear-history actions.
@MainActor
final class ChatInfoViewModel: ObservableObject {
    @Published private(set) var state: ViewState<ChatInfo> = .idle
    @Published private(set) var isLeaving = false
    @Published private(set) var isMutatingPrefs = false
    @Published private(set) var leaveErrorMessage: String?
    @Published private(set) var actionErrorMessage: String?
    @Published private(set) var mediaPreview: [Message] = []

    let chatId: String
    let currentUserId: String

    /// Exposed for nested Info destinations (media / search).
    let chatRepository: ChatRepository
    private var loadTask: Task<Void, Never>?
    /// In-flight mute without `@Published` — prevents UI dimming glitches.
    private var isMutatingMute = false

    init(
        chatId: String,
        currentUserId: String,
        chatRepository: ChatRepository
    ) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatRepository = chatRepository
    }

    var navigationTitle: String { "Info" }

    /// DM: the other person. Group: everyone (self included, marked in UI).
    func displayParticipants(from info: ChatInfo) -> [User] {
        if info.type == .direct {
            return info.participants.filter { $0.id != currentUserId }
        }
        return info.participants.sorted { lhs, rhs in
            if lhs.id == currentUserId { return false }
            if rhs.id == currentUserId { return true }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.performLoad()
        }
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    func setMuted(_ muted: Bool) async {
        guard case var .loaded(info) = state else { return }
        guard !isMutatingMute else { return }
        let previous = info.isMuted
        // Optimistic UI — no published busy flag (avoids dimming the whole action grid).
        info.isMuted = muted
        state = .loaded(info)
        isMutatingMute = true
        actionErrorMessage = nil
        defer { isMutatingMute = false }

        do {
            try await chatRepository.setChatMuted(chatId: chatId, muted: muted)
            NotificationCenter.default.post(name: .circleLinkChatListShouldReload, object: nil)
        } catch {
            info.isMuted = previous
            state = .loaded(info)
            actionErrorMessage = error.localizedDescription
        }
    }

    /// Leaves the chat only (not the community). Returns `true` on success.
    @discardableResult
    func leaveChat() async -> Bool {
        guard !isLeaving else { return false }
        isLeaving = true
        leaveErrorMessage = nil
        defer { isLeaving = false }

        do {
            try await chatRepository.leaveChat(chatId: chatId)
            return true
        } catch {
            leaveErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func hideChat() async -> Bool {
        guard !isMutatingPrefs else { return false }
        isMutatingPrefs = true
        actionErrorMessage = nil
        defer { isMutatingPrefs = false }

        do {
            try await chatRepository.hideChat(chatId: chatId)
            return true
        } catch {
            actionErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteDirectChat() async -> Bool {
        guard !isMutatingPrefs else { return false }
        isMutatingPrefs = true
        actionErrorMessage = nil
        defer { isMutatingPrefs = false }

        do {
            try await chatRepository.deleteDirectChat(chatId: chatId)
            return true
        } catch {
            actionErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func clearHistory() async -> Bool {
        guard !isMutatingPrefs else { return false }
        isMutatingPrefs = true
        actionErrorMessage = nil
        defer { isMutatingPrefs = false }

        do {
            try await chatRepository.clearChatHistory(chatId: chatId)
            if case var .loaded(info) = state {
                info.clearedAt = Date()
                state = .loaded(info)
            }
            mediaPreview = []
            NotificationCenter.default.post(
                name: .circleLinkChatHistoryCleared,
                object: nil,
                userInfo: [ChatHistoryClearedUserInfoKey.chatId: chatId]
            )
            return true
        } catch {
            actionErrorMessage = error.localizedDescription
            return false
        }
    }

    func clearLeaveError() {
        leaveErrorMessage = nil
    }

    func clearActionError() {
        actionErrorMessage = nil
    }

    private func performLoad() async {
        state = .loading
        leaveErrorMessage = nil
        actionErrorMessage = nil

        do {
            let info = try await chatRepository.fetchChatInfo(chatId: chatId)
            guard !Task.isCancelled else { return }
            state = .loaded(info)
            await loadMediaPreview()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }

    private func loadMediaPreview() async {
        do {
            mediaPreview = try await chatRepository.fetchChatMedia(
                chatId: chatId,
                limit: 4,
                before: nil
            )
        } catch {
            mediaPreview = []
        }
    }
}

enum ChatHistoryClearedUserInfoKey {
    static let chatId = "chatId"
}

extension Notification.Name {
    static let circleLinkChatHistoryCleared = Notification.Name("circleLinkChatHistoryCleared")
    static let circleLinkChatListShouldReload = Notification.Name("circleLinkChatListShouldReload")
    /// Open / scroll to a message after Chat Info search.
    static let circleLinkRevealChatMessage = Notification.Name("circleLinkRevealChatMessage")
}

enum ChatRevealMessageUserInfoKey {
    static let chatId = "chatId"
    static let messageId = "messageId"
}
