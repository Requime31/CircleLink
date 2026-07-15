import Foundation

enum ConnectionStatus: String, Codable, Equatable, Sendable {
    case pending
    case accepted
    case declined
}
