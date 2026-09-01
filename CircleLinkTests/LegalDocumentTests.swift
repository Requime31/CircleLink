import Foundation
import Testing
@testable import CircleLink

@MainActor
struct LegalDocumentTests {
    @Test func catalogContainsTermsAndPrivacy() {
        #expect(LegalDocuments.all.map(\.kind) == [.termsOfService, .privacyPolicy])
    }

    @Test func documentsHaveRequiredNonEmptySections() {
        let requiredTerms = [
            "terms-service-purpose", "terms-eligibility", "terms-user-content",
            "terms-conduct", "terms-moderation-blocking", "terms-account-deletion",
            "terms-services", "terms-changes", "terms-contact"
        ]
        let requiredPrivacy = [
            "privacy-data-categories", "privacy-use", "privacy-providers", "privacy-push",
            "privacy-retention-deletion", "privacy-age", "privacy-changes", "privacy-contact"
        ]

        verify(document: LegalDocuments.termsOfService, requiredSectionIDs: requiredTerms)
        verify(document: LegalDocuments.privacyPolicy, requiredSectionIDs: requiredPrivacy)
    }

    @Test func everyCatalogSectionHasReadableContent() {
        for document in LegalDocuments.all {
            #expect(document.sections.isEmpty == false)
            for section in document.sections {
                #expect(!section.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(!section.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(section.paragraphs.isEmpty == false)
                #expect(section.paragraphs.allSatisfy {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                })
            }
        }
    }

    @Test func draftDocumentsExposeReviewAndContactPlaceholders() {
        for document in LegalDocuments.all {
            #expect(document.status == .draft)
            #expect(document.lastUpdated == nil)
            let text = document.sections.flatMap(\.paragraphs).joined(separator: " ")
            #expect(text.localizedCaseInsensitiveContains("requires legal review"))
            #expect(text.localizedCaseInsensitiveContains("email to be added before release"))
        }
    }

    @Test func documentAndSectionIDsAreUnique() {
        let documentIDs = LegalDocuments.all.map(\.id)
        #expect(Set(documentIDs).count == documentIDs.count)

        let sectionIDs = LegalDocuments.all.flatMap { $0.sections.map(\.id) }
        #expect(Set(sectionIDs).count == sectionIDs.count)
    }

    private func verify(document: LegalDocument, requiredSectionIDs: [String]) {
        #expect(!document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(document.sections.isEmpty == false)

        for requiredID in requiredSectionIDs {
            let section = document.sections.first { $0.id == requiredID }
            #expect(section != nil, "Missing required section: \(requiredID)")
            #expect(section?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            #expect(section?.paragraphs.isEmpty == false)
            #expect(section?.paragraphs.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } == true)
        }
    }
}
