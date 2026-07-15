import Combine
import Foundation

@MainActor
final class ConnectViewModel: ObservableObject {
    private let connectionRepository: ConnectionRepository

    init(connectionRepository: ConnectionRepository) {
        self.connectionRepository = connectionRepository
    }
}
