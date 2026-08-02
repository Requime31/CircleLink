import Foundation

nonisolated enum ReportReason: String, Codable, CaseIterable, Sendable {
    case spam
    case harassment
    case inappropriate
    case other

    var title: String {
        switch self {
        case .spam:
            return "Spam"
        case .harassment:
            return "Harassment"
        case .inappropriate:
            return "Inappropriate content"
        case .other:
            return "Other"
        }
    }
}
