import Combine
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[ChatSummary]> = .idle

    private let chatRepository: ChatRepository

    init(chatRepository: ChatRepository) {
        self.chatRepository = chatRepository
    }

    func loadChats() async {
        state = .loading

        do {
            let chats = try await chatRepository.fetchChats()
            state = chats.isEmpty ? .empty : .loaded(chats)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        state = .idle
    }
}
