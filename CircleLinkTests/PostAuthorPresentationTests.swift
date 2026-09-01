import Testing
@testable import CircleLink

struct PostAuthorPresentationTests {
    @Test func foreignAuthorSelectsCorrectIdOnce() {
        let presentation = PostAuthorPresentation(
            author: User(id: "peer-1", displayName: "Alex"),
            currentUserId: "user-1"
        )
        var selectedIds: [String] = []

        presentation.selectAuthor { selectedIds.append($0) }

        #expect(selectedIds == ["peer-1"])
        #expect(presentation.displayName == "Alex")
    }

    @Test func ownAuthorDoesNotNavigate() {
        let presentation = PostAuthorPresentation(
            author: User(id: "user-1", displayName: "Me"),
            currentUserId: "user-1"
        )
        var selectionCount = 0

        presentation.selectAuthor { _ in selectionCount += 1 }

        #expect(selectionCount == 0)
        #expect(presentation.selectableUserId == nil)
    }

    @Test func missingAndDeactivatedAuthorsAreDeletedAndDoNotNavigate() {
        let missing = PostAuthorPresentation(author: nil, currentUserId: "user-1")
        let deactivated = PostAuthorPresentation(
            author: User(id: "peer-1", displayName: "Old name", accountState: .deactivated),
            currentUserId: "user-1"
        )
        var selectionCount = 0

        missing.selectAuthor { _ in selectionCount += 1 }
        deactivated.selectAuthor { _ in selectionCount += 1 }

        #expect(missing.displayName == "Deleted User")
        #expect(deactivated.displayName == "Deleted User")
        #expect(selectionCount == 0)
    }

    @Test func blankAuthorIdIsDeletedAndDoesNotNavigate() {
        let presentation = PostAuthorPresentation(
            author: User(id: "   ", displayName: "Ghost"),
            currentUserId: "user-1"
        )
        var selectionCount = 0

        presentation.selectAuthor { _ in selectionCount += 1 }

        #expect(presentation.displayName == "Deleted User")
        #expect(selectionCount == 0)
    }
}
