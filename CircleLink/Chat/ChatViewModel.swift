import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var messages: [ChatMessageItem] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    /// From chat doc — used for Peer Profile Connect in group chats.
    @Published private(set) var communityId: String?
    @Published private(set) var isGroupChat = false
    /// Success / error copy for report & block alerts in `ChatSheetView`.
    @Published private(set) var moderationMessage: String?
    @Published private(set) var moderationErrorMessage: String?

    let chatId: String
    /// Navigation title — peer name for direct, community name for group.
    let chatTitle: String
    /// Direct-chat peer only; `nil` for group chats.
    let peerUserId: String?
    private let chatRepository: ChatRepository
    private let moderationRepository: ModerationRepository?
    private let currentUserId: String
    private let onPeerBlocked: (() -> Void)?
    private let pageSize = 30

    private var liveMessagesTask: Task<Void, Never>?
    private var loadInitialTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var moderationTask: Task<Void, Never>?
    /// Per-message send/retry — keeps optimistic multi-send, blocks duplicate retry.
    private var sendTasks: [String: Task<Void, Never>] = [:]
    /// Ignores stale history results when a newer load supersedes or screen disappears.
    private var loadGeneration = 0
    private var mapper: ChatMessageMapper
    private var knownMessageIds = Set<String>()
    private var knownClientMessageIds = Set<String>()
    /// Prevents overlapping report/block requests.
    private var isModerating = false

    private var reconciler: ChatLiveMessageReconciler {
        ChatLiveMessageReconciler(mapper: mapper)
    }

    private var identifierState: ChatLiveMessageReconciler.State {
        ChatLiveMessageReconciler.State(
            messages: messages,
            knownMessageIds: knownMessageIds,
            knownClientMessageIds: knownClientMessageIds
        )
    }

    var canModeratePeer: Bool {
        peerUserId != nil && moderationRepository != nil
    }

    init(
        chatId: String,
        currentUserId: String,
        chatRepository: ChatRepository,
        chatTitle: String = "Chat",
        peerUserId: String? = nil,
        moderationRepository: ModerationRepository? = nil,
        onPeerBlocked: (() -> Void)? = nil
    ) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatRepository = chatRepository
        self.chatTitle = chatTitle
        self.peerUserId = peerUserId
        self.moderationRepository = moderationRepository
        self.onPeerBlocked = onPeerBlocked
        self.mapper = ChatMessageMapper(currentUserId: currentUserId)
    }

    deinit {
        // Cancelling terminates observeLiveMessages AsyncStream → ListenerRegistration.remove().
        liveMessagesTask?.cancel()
        loadInitialTask?.cancel()
        loadMoreTask?.cancel()
        moderationTask?.cancel()
        for task in sendTasks.values {
            task.cancel()
        }
    }

    // MARK: - Lifecycle

    func onAppear() {
        // Start only after history is loaded so the first listener snapshot can be
        // filtered against known ids / oldest loaded date (avoids dumping older history).
        if loadState == .loaded {
            startObservingLiveMessages()
        }
    }

    func onDisappear() {
        cancelScreenOwnedWork()
    }

    // MARK: - Moderation (direct chats)

    func reportPeer(reason: ReportReason) async {
        guard let peerUserId, let moderationRepository, !isModerating else { return }

        moderationTask?.cancel()
        isModerating = true
        moderationMessage = nil
        moderationErrorMessage = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isModerating = false }

            do {
                try await moderationRepository.reportUser(
                    userId: peerUserId,
                    reason: reason,
                    chatId: self.chatId,
                    communityId: nil
                )
                guard !Task.isCancelled else { return }
                self.moderationMessage = "Thanks — we’ll review this report."
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.moderationErrorMessage = error.localizedDescription
            }
        }
        moderationTask = task
        await task.value
    }

    func blockPeer() async {
        guard let peerUserId, let moderationRepository, !isModerating else { return }

        moderationTask?.cancel()
        isModerating = true
        moderationMessage = nil
        moderationErrorMessage = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isModerating = false }

            do {
                try await moderationRepository.blockUser(peerUserId)
                guard !Task.isCancelled else { return }
                self.onPeerBlocked?()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.moderationErrorMessage = error.localizedDescription
            }
        }
        moderationTask = task
        await task.value
    }

    func clearModerationFeedback() {
        moderationMessage = nil
        moderationErrorMessage = nil
    }

    // MARK: - Load

    func loadInitialMessages() async {
        loadInitialTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        // Only show loading when this generation still owns the screen.
        loadState = .loading

        let task = Task { @MainActor [weak self] in
            await self?.performLoadInitial(generation: generation)
        }
        loadInitialTask = task
        await task.value
    }

    func loadMoreMessagesIfNeeded(currentIndex: Int) async {
        guard canLoadMore, !isLoadingMore, loadMoreTask == nil else { return }
        guard currentIndex >= messages.count - 3 else { return }
        guard let oldestDate = messages.last?.createdAt else { return }

        let generation = loadGeneration
        isLoadingMore = true

        let task = Task { @MainActor [weak self] in
            await self?.performLoadMore(before: oldestDate, generation: generation)
        }
        loadMoreTask = task
        await task.value
        if loadMoreTask == task {
            loadMoreTask = nil
        }
    }

    // MARK: - Send

    func send(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await sendMessage(text: trimmed, imageData: nil)
    }

    func send(imageData: Data) async {
        await sendMessage(text: nil, imageData: imageData)
    }

    func retry(clientMessageId: String) async {
        // Ignore double-tap while the same message is already sending/retrying.
        guard sendTasks[clientMessageId] == nil else { return }
        guard let item = messages.first(where: { $0.clientMessageId == clientMessageId }),
              item.status == .failed else { return }

        updateMessageStatus(clientMessageId: clientMessageId, status: .sending)

        let task = Task { @MainActor [weak self] in
            await self?.performSend(
                text: item.text,
                imageData: item.localImageData,
                clientMessageId: clientMessageId
            )
        }
        sendTasks[clientMessageId] = task
        await task.value
        if sendTasks[clientMessageId] == task {
            sendTasks[clientMessageId] = nil
        }
    }

    // MARK: - Live Messages

    private func startObservingLiveMessages() {
        liveMessagesTask?.cancel()
        liveMessagesTask = Task { [weak self] in
            guard let self else { return }

            for await message in self.chatRepository.observeLiveMessages(chatId: self.chatId) {
                guard !Task.isCancelled else { break }
                self.handleLiveMessage(message)
            }
        }
    }

    private func handleLiveMessage(_ message: Message) {
        applyState(reconciler.apply(live: message, to: identifierState))
    }

    // MARK: - Private

    private func cancelScreenOwnedWork() {
        loadGeneration += 1
        loadInitialTask?.cancel()
        loadInitialTask = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
        isLoadingMore = false
        moderationTask?.cancel()
        moderationTask = nil
        isModerating = false
        liveMessagesTask?.cancel()
        liveMessagesTask = nil
        // Avoid a stuck spinner if the screen went away mid-load.
        if case .loading = loadState {
            loadState = .idle
        }
        // In-flight sends keep running with weak self so optimistic UX can finish
        // without writing if the VM is already gone.
    }

    private func performLoadInitial(generation: Int) async {
        async let participantsLoad: Void = loadParticipants(generation: generation)
        async let fetchedMessages = chatRepository.fetchMessages(
            chatId: chatId,
            limit: pageSize,
            before: nil
        )

        do {
            _ = await participantsLoad
            let fetched = try await fetchedMessages
            guard !Task.isCancelled, generation == loadGeneration else { return }
            applyState(ChatLiveMessageReconciler.State.rebuilt(from: mapper.mapHistory(fetched)))
            canLoadMore = fetched.count == pageSize
            loadState = .loaded
            startObservingLiveMessages()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            loadState = .error(error.localizedDescription)
        }
    }

    private func performLoadMore(before oldestDate: Date, generation: Int) async {
        defer {
            if generation == loadGeneration {
                isLoadingMore = false
            }
        }

        do {
            let fetched = try await chatRepository.fetchMessages(
                chatId: chatId,
                limit: pageSize,
                before: oldestDate
            )
            guard !Task.isCancelled, generation == loadGeneration else { return }
            let olderItems = mapper.mapHistory(fetched)
            let uniqueOlder = reconciler.uniqueOlder(olderItems, given: identifierState)
            messages.append(contentsOf: uniqueOlder)
            trackIdentifiers(for: uniqueOlder)
            canLoadMore = fetched.count == pageSize
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            loadState = .error(error.localizedDescription)
        }
    }

    private func sendMessage(text: String?, imageData: Data?) async {
        let clientMessageId = UUID().uuidString
        let optimistic = ChatMessageItem.optimistic(
            chatId: chatId,
            senderId: currentUserId,
            text: text,
            imageData: imageData,
            clientMessageId: clientMessageId
        )
        messages.insert(optimistic, at: 0)
        trackIdentifiers(for: [optimistic])

        let task = Task { @MainActor [weak self] in
            await self?.performSend(
                text: text,
                imageData: imageData,
                clientMessageId: clientMessageId
            )
        }
        sendTasks[clientMessageId] = task
        await task.value
        if sendTasks[clientMessageId] == task {
            sendTasks[clientMessageId] = nil
        }
    }

    private func performSend(
        text: String?,
        imageData: Data?,
        clientMessageId: String
    ) async {
        do {
            try await chatRepository.sendMessage(
                chatId: chatId,
                text: text,
                image: imageData,
                clientMessageId: clientMessageId
            )
            guard !Task.isCancelled else { return }
            updateMessageStatus(
                clientMessageId: clientMessageId,
                status: .sent,
                useClientIdAsMessageId: true
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            updateMessageStatus(clientMessageId: clientMessageId, status: .failed)
        }
    }

    private func loadParticipants(generation: Int) async {
        do {
            let info = try await chatRepository.fetchChatInfo(chatId: chatId)
            guard !Task.isCancelled, generation == loadGeneration else { return }
            communityId = info.communityId
            isGroupChat = info.type == .group
            var map: [String: User] = [:]
            for user in info.participants {
                map[user.id] = user
            }
            mapper.participantsById = map
            // Refresh labels/avatars if messages already loaded.
            if !messages.isEmpty {
                messages = mapper.redecorate(messages)
            }
        } catch {
            // Participants are best-effort — chat still works without avatars.
        }
    }

    private func updateMessageStatus(
        clientMessageId: String,
        status: MessageStatus,
        useClientIdAsMessageId: Bool = false
    ) {
        guard let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) else {
            return
        }
        let updated = ChatSendStatusUpdater.applying(
            status: status,
            to: messages[index],
            useClientIdAsMessageId: useClientIdAsMessageId,
            mapper: mapper
        )
        messages[index] = updated
        knownMessageIds.insert(updated.id)
        knownClientMessageIds.insert(updated.clientMessageId)
    }

    private func applyState(_ state: ChatLiveMessageReconciler.State) {
        messages = state.messages
        knownMessageIds = state.knownMessageIds
        knownClientMessageIds = state.knownClientMessageIds
    }

    private func trackIdentifiers(for items: [ChatMessageItem]) {
        for item in items {
            knownMessageIds.insert(item.id)
            knownClientMessageIds.insert(item.clientMessageId)
        }
    }
}
