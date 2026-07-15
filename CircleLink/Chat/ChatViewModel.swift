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

    init(chatId: String, currentUserId: String, chatRepository: ChatRepository) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        self.chatRepository = chatRepository
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
            canLoadMore = fetched.count == pageSize
            loadState = .loaded
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
            let existingIds = Set(messages.map(\.clientMessageId))
            let uniqueOlder = olderItems.filter { !existingIds.contains($0.clientMessageId) }
            messages.append(contentsOf: uniqueOlder)
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
        messages[index] = transform(messages[index])
    }
}
