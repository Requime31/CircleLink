import Combine
import Foundation

/// Loads participants for Chat Info / Members. Owns leave-chat for groups.
@MainActor
final class ChatInfoViewModel: ObservableObject {
    @Published private(set) var state: ViewState<ChatInfo> = .idle
    @Published private(set) var isLeaving = false
    @Published private(set) var leaveErrorMessage: String?

    let chatId: String
    let currentUserId: String

    private let chatRepository: ChatRepository
    private var loadTask: Task<Void, Never>?
    private var leaveTask: Task<Bool, Never>?

    init(
        chatId: String,
        currentUserId: String,
        chatRepository: ChatRepository
    ) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatRepository = chatRepository
    }

    var navigationTitle: String {
        guard case let .loaded(info) = state else {
            return "Chat Info"
        }
        return info.type == .group ? "Members" : "Chat Info"
    }

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

    /// Leaves the chat only (not the community). Returns `true` on success.
    @discardableResult
    func leaveChat() async -> Bool {
        guard !isLeaving else { return false }

        leaveTask?.cancel()
        isLeaving = true
        leaveErrorMessage = nil

        let task = Task { @MainActor [weak self] -> Bool in
            guard let self else { return false }
            defer { self.isLeaving = false }

            do {
                try await self.chatRepository.leaveChat(chatId: self.chatId)
                guard !Task.isCancelled else { return false }
                return true
            } catch is CancellationError {
                return false
            } catch {
                guard !Task.isCancelled else { return false }
                self.leaveErrorMessage = error.localizedDescription
                return false
            }
        }
        leaveTask = task
        return await task.value
    }

    func clearLeaveError() {
        leaveErrorMessage = nil
    }

    private func performLoad() async {
        state = .loading
        leaveErrorMessage = nil

        do {
            let info = try await chatRepository.fetchChatInfo(chatId: chatId)
            guard !Task.isCancelled else { return }
            state = .loaded(info)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }
}
