import Foundation

nonisolated enum ChatType: String, Codable, Equatable, Sendable {
    case direct
    case group
}
