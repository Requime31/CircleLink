import Foundation

nonisolated struct Community: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
    let interestTag: String
    var memberCount: Int
}
