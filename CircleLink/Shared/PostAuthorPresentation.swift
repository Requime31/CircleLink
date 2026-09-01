import Foundation

/// Presentation-only policy shared by post rows. Navigation remains owned by the screen.
struct PostAuthorPresentation: Equatable {
    let displayName: String
    let selectableUserId: String?

    init(author: User?, currentUserId: String?) {
        guard let author, author.isSociallyAvailable else {
            displayName = "Deleted User"
            selectableUserId = nil
            return
        }

        let userId = author.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else {
            displayName = "Deleted User"
            selectableUserId = nil
            return
        }

        let name = author.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = name.isEmpty ? "Member" : name
        selectableUserId = userId == currentUserId ? nil : userId
    }

    func selectAuthor(perform action: (String) -> Void) {
        guard let selectableUserId else { return }
        action(selectableUserId)
    }
}
