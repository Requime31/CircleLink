import Combine
import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    private let chatRepository: ChatRepository

    init(chatRepository: ChatRepository) {
        self.chatRepository = chatRepository
    }
}
