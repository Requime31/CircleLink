import Foundation

enum MessageStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case failed
}
