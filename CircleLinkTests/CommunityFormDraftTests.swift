import Foundation
import Testing
@testable import CircleLink

@MainActor
struct CommunityFormDraftTests {
    @Test func editDraftPrefillsMetadataAndKeepsCoverUnchanged() {
        let community = Community(
            id: "community-1", name: "Original", description: "About", interestTag: "Art",
            memberCount: 3, coverImageURL: URL(string: "https://example.com/cover.jpg")
        )

        let draft = CommunityFormDraft(community: community)

        #expect(draft.name == "Original")
        #expect(draft.description == "About")
        #expect(draft.interestTag == "Art")
        #expect(draft.coverEdit == .unchanged)
        #expect(!draft.isDirty)
    }

    @Test func editDraftTracksReplaceAndRemoveCover() {
        let community = Community(
            id: "community-1", name: "Original", description: "", interestTag: "Art",
            memberCount: 3, coverImageURL: URL(string: "https://example.com/cover.jpg")
        )
        var draft = CommunityFormDraft(community: community)

        draft.selectedCoverData = Data([4, 5])
        #expect(draft.coverEdit == .replace(Data([4, 5])))
        draft.selectedCoverData = nil
        draft.removesExistingCover = true
        #expect(draft.coverEdit == .remove)
        #expect(draft.isDirty)
    }
}
