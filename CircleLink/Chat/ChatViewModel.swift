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

    let chatId: String
    private let chatRepository: ChatRepository
    private let currentUserId: String
    private let pageSize = 30
    private let onMeaningfulAction: (() async -> Void)?

    private var liveMessagesTask: Task<Void, Never>?
    private var knownMessageIds = Set<String>()
    private var knownClientMessageIds = Set<String>()

    init(
        chatId: String,
        currentUserId: String,
        chatRepository: ChatRepository,
        onMeaningfulAction: (() async -> Void)? = nil
    ) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatRepository = chatRepository
        self.onMeaningfulAction = onMeaningfulAction
    }

    deinit {
        // Cancelling terminates observeLiveMessages AsyncStream → ListenerRegistration.remove().
        liveMessagesTask?.cancel()
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
        liveMessagesTask?.cancel()
        liveMessagesTask = nil
    }

    // MARK: - Load

    func loadInitialMessages() async {
        guard loadState != .loading else { return }
        loadState = .loading

        do {
            let fetched = try await chatRepository.fetchMessages(
                chatId: chatId,
                limit: pageSize,
                before: nil
            )
            messages = mapToDisplayItems(fetched)
            rebuildKnownIdentifiers()
            canLoadMore = fetched.count == pageSize
            loadState = .loaded
            startObservingLiveMessages()
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func loadMoreMessagesIfNeeded(currentIndex: Int) async {
        guard canLoadMore, !isLoadingMore else { return }
        guard currentIndex >= messages.count - 3 else { return }
        guard let oldestDate = messages.last?.createdAt else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let fetched = try await chatRepository.fetchMessages(
                chatId: chatId,
                limit: pageSize,
                before: oldestDate
            )
            let olderItems = mapToDisplayItems(fetched)
            let uniqueOlder = olderItems.filter { item in
                !knownMessageIds.contains(item.id) && !knownClientMessageIds.contains(item.clientMessageId)
            }
            messages.append(contentsOf: uniqueOlder)
            trackIdentifiers(for: uniqueOlder)
            canLoadMore = fetched.count == pageSize
        } catch {
            loadState = .error(error.localizedDescription)
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

        do {
            try await chatRepository.sendMessage(
                chatId: chatId,
                text: text,
                image: imageData,
                clientMessageId: clientMessageId
            )
            updateMessage(clientMessageId: clientMessageId) { item in
                ChatMessageItem(
                    message: Message(
                        id: clientMessageId,
                        chatId: item.chatId,
                        senderId: item.senderId,
                        text: item.text,
                        imageURL: item.imageURL,
                        createdAt: item.createdAt,
                        clientMessageId: clientMessageId,
                        status: .sent
                    ),
                    currentUserId: currentUserId,
                    senderLabel: item.senderLabel,
                    localImageData: item.localImageData
                )
            }
            await onMeaningfulAction?()
        } catch {
            updateMessage(clientMessageId: clientMessageId) { item in
                ChatMessageItem(
                    message: Message(
                        id: item.id,
                        chatId: item.chatId,
                        senderId: item.senderId,
                        text: item.text,
                        imageURL: item.imageURL,
                        createdAt: item.createdAt,
                        clientMessageId: clientMessageId,
                        status: .failed
                    ),
                    currentUserId: currentUserId,
                    senderLabel: item.senderLabel,
                    localImageData: item.localImageData
                )
            }
        }
    }

    func retry(clientMessageId: String) async {
        guard let item = messages.first(where: { $0.clientMessageId == clientMessageId }),
              item.status == .failed else { return }

        updateMessage(clientMessageId: clientMessageId) { item in
            ChatMessageItem(
                message: Message(
                    id: item.id,
                    chatId: item.chatId,
                    senderId: item.senderId,
                    text: item.text,
                    imageURL: item.imageURL,
                    createdAt: item.createdAt,
                    clientMessageId: clientMessageId,
                    status: .sending
                ),
                currentUserId: currentUserId,
                senderLabel: item.senderLabel,
                localImageData: item.localImageData
            )
        }

        do {
            try await chatRepository.sendMessage(
                chatId: chatId,
                text: item.text,
                image: item.localImageData,
                clientMessageId: clientMessageId
            )
            updateMessage(clientMessageId: clientMessageId) { item in
                ChatMessageItem(
                    message: Message(
                        id: clientMessageId,
                        chatId: item.chatId,
                        senderId: item.senderId,
                        text: item.text,
                        imageURL: item.imageURL,
                        createdAt: item.createdAt,
                        clientMessageId: clientMessageId,
                        status: .sent
                    ),
                    currentUserId: currentUserId,
                    senderLabel: item.senderLabel,
                    localImageData: item.localImageData
                )
            }
            await onMeaningfulAction?()
        } catch {
            updateMessage(clientMessageId: clientMessageId) { item in
                ChatMessageItem(
                    message: Message(
                        id: item.id,
                        chatId: item.chatId,
                        senderId: item.senderId,
                        text: item.text,
                        imageURL: item.imageURL,
                        createdAt: item.createdAt,
                        clientMessageId: clientMessageId,
                        status: .failed
                    ),
                    currentUserId: currentUserId,
                    senderLabel: item.senderLabel,
                    localImageData: item.localImageData
                )
            }
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
        let clientMessageId = message.clientMessageId ?? message.id

        if knownMessageIds.contains(message.id) {
            return
        }

        if knownClientMessageIds.contains(clientMessageId) {
            if let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) {
                let existing = messages[index]
                messages[index] = ChatMessageItem(
                    message: Message(
                        id: message.id,
                        chatId: message.chatId,
                        senderId: message.senderId,
                        text: message.text ?? existing.text,
                        imageURL: message.imageURL ?? existing.imageURL,
                        createdAt: message.createdAt,
                        clientMessageId: clientMessageId,
                        status: .sent
                    ),
                    currentUserId: currentUserId,
                    senderLabel: existing.senderLabel,
                    localImageData: existing.localImageData
                )
                knownMessageIds.insert(message.id)
            }
            return
        }

        // First snapshot can include messages older than the current page.
        // Those belong to pagination — do not insert them into the live list.
        if let oldestLoaded = messages.last?.createdAt, message.createdAt < oldestLoaded {
            return
        }

        let item = ChatMessageItem(message: message, currentUserId: currentUserId)
        messages.insert(item, at: 0)
        trackIdentifiers(for: [item])
    }

    // MARK: - Private

    private func mapToDisplayItems(_ messages: [Message]) -> [ChatMessageItem] {
        messages
            .map { ChatMessageItem(message: $0, currentUserId: currentUserId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func updateMessage(
        clientMessageId: String,
        transform: (ChatMessageItem) -> ChatMessageItem
    ) {
        guard let index = messages.firstIndex(where: { $0.clientMessageId == clientMessageId }) else {
            return
        }
        let updated = transform(messages[index])
        messages[index] = updated
        knownMessageIds.insert(updated.id)
        knownClientMessageIds.insert(updated.clientMessageId)
    }

    private func rebuildKnownIdentifiers() {
        knownMessageIds = Set(messages.map(\.id))
        knownClientMessageIds = Set(messages.map(\.clientMessageId))
    }

    private func trackIdentifiers(for items: [ChatMessageItem]) {
        for item in items {
            knownMessageIds.insert(item.id)
            knownClientMessageIds.insert(item.clientMessageId)
        }
    }
}
