import Testing
@testable import CircleLink

struct CommunityContentPolicyTests {
    @Test func trimsOuterWhitespaceAndRejectsEmptyName() throws {
        #expect(throws: CommunityContentValidationError.nameRequired) {
            try CommunityContentPolicy.validate(name: " \n ", description: "Description")
        }

        let content = try CommunityContentPolicy.validate(
            name: "  Swift Circle \n",
            description: "\n Friendly people  "
        )
        #expect(content.name == "Swift Circle")
        #expect(content.description == "Friendly people")
    }

    @Test(arguments: [1, 30])
    func acceptsNameBoundaries(length: Int) throws {
        let content = try CommunityContentPolicy.validate(
            name: String(repeating: "a", count: length),
            description: ""
        )
        #expect(content.name.count == length)
    }

    @Test func rejectsNameAboveBoundary() {
        #expect(throws: CommunityContentValidationError.nameTooLong) {
            try CommunityContentPolicy.validate(
                name: String(repeating: "a", count: 31),
                description: ""
            )
        }
    }

    @Test func acceptsAndRejectsDescriptionBoundaries() throws {
        let accepted = try CommunityContentPolicy.validate(
            name: "Swift",
            description: String(repeating: "d", count: 500)
        )
        #expect(accepted.description.count == 500)

        #expect(throws: CommunityContentValidationError.descriptionTooLong) {
            try CommunityContentPolicy.validate(
                name: "Swift",
                description: String(repeating: "d", count: 501)
            )
        }
    }

    @Test func countsEmojiAndCombiningMarksAsGraphemeClusters() throws {
        let familyEmoji = "👨‍👩‍👧‍👦"
        let combiningCharacter = "e\u{301}"
        let name = String(repeating: familyEmoji, count: 15)
            + String(repeating: combiningCharacter, count: 15)

        let content = try CommunityContentPolicy.validate(name: name, description: familyEmoji)

        #expect(content.name.count == 30)
        #expect(content.description.count == 1)
    }

    @Test func legacyOversizedNameGetsSafeDisplayWithoutMutatingSource() {
        let legacyName = String(repeating: "Long community ", count: 20)

        let displayName = CommunityContentPolicy.safeDisplayName(legacyName)

        #expect(displayName.count == CommunityContentPolicy.nameLimit)
        #expect(displayName.hasSuffix("…"))
        #expect(legacyName.count > CommunityContentPolicy.nameLimit)
    }

    @Test func oversizedPasteIsBoundedOnGraphemeBoundary() {
        let emoji = "👩🏽‍💻"
        let draft = String(repeating: emoji, count: 2_000)

        #expect(
            CommunityContentPolicy.boundedDescriptionDraft(draft).count
                == CommunityContentPolicy.descriptionDraftSafetyLimit
        )
    }
}
