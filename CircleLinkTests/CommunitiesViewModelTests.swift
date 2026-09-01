import Foundation
import Testing
import UIKit
@testable import CircleLink

@MainActor
struct CommunitiesViewModelTests {
    @Test func loadCommunitiesSetsLoadedState() async {
        let repo = MockCommunityRepository()
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        await viewModel.loadCommunities()

        if case let .loaded(communities) = viewModel.state {
            #expect(communities.count == 1)
            #expect(communities.first?.id == "community-1")
        } else {
            Issue.record("Expected loaded communities")
        }
    }

    @Test func loadCommunitiesSetsEmptyWhenNone() async {
        let repo = MockCommunityRepository()
        repo.communities = []
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        await viewModel.loadCommunities()

        if case .empty = viewModel.state {
            // ok
        } else {
            Issue.record("Expected empty state")
        }
    }

    @Test func loadCommunitiesPropagatesError() async {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "Network down" }
        }

        let repo = MockCommunityRepository()
        repo.fetchCommunitiesError = Boom()
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        await viewModel.loadCommunities()

        if case let .error(message) = viewModel.state {
            #expect(message == "Network down")
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test func quietRefreshErrorKeepsLoadedContent() async {
        struct Boom: Error {}

        let repo = MockCommunityRepository()
        let viewModel = CommunitiesViewModel(communityRepository: repo)
        await viewModel.loadCommunities()
        let loadedCommunities = viewModel.allCommunities

        repo.fetchCommunitiesError = Boom()
        await viewModel.refreshCommunities(showLoading: false)

        #expect(viewModel.state == .loaded(loadedCommunities))
        #expect(viewModel.allCommunities == loadedCommunities)
    }

    @Test func clearFiltersClearsSearchAndSelectedCategory() async {
        let viewModel = CommunitiesViewModel(communityRepository: MockCommunityRepository())
        await viewModel.loadCommunities()
        viewModel.searchQuery = "swift"
        viewModel.selectedInterestTag = "Tech"

        viewModel.clearFilters()

        #expect(viewModel.searchQuery.isEmpty)
        #expect(viewModel.selectedInterestTag == nil)
    }

    @Test func resetFormReturnsToIdle() async {
        let viewModel = CommunitiesViewModel(communityRepository: MockCommunityRepository())
        await viewModel.loadCommunities()

        viewModel.resetForm()

        if case .idle = viewModel.state {
            // ok
        } else {
            Issue.record("Expected idle after reset")
        }
    }

    @Test func discoverySectionsRankPopularAndRecentCommunities() async {
        let repo = MockCommunityRepository()
        repo.communities = [
            Community(
                id: "older-popular",
                name: "Popular",
                description: "",
                interestTag: "Art",
                memberCount: 100,
                createdAt: Date(timeIntervalSince1970: 10)
            ),
            Community(
                id: "newer",
                name: "New",
                description: "",
                interestTag: "Art",
                memberCount: 5,
                createdAt: Date(timeIntervalSince1970: 20)
            )
        ]
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        await viewModel.loadCommunities()

        #expect(viewModel.suggestedCommunities.map(\.id) == ["older-popular", "newer"])
        #expect(viewModel.newCommunities.map(\.id) == ["newer", "older-popular"])
    }

    @Test func allCommunitiesPreservesLoadedCatalogOrder() async {
        let repo = MockCommunityRepository()
        repo.communities = [
            community(id: "second", name: "Zulu"),
            community(id: "first", name: "Alpha")
        ]
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        await viewModel.loadCommunities()

        #expect(viewModel.allCommunities.map(\.id) == ["second", "first"])
    }

    @Test func popularSortsByMemberCountDescending() {
        let communities = [
            community(id: "small", name: "Small", memberCount: 2),
            community(id: "large", name: "Large", memberCount: 20),
            community(id: "medium", name: "Medium", memberCount: 10)
        ]

        let sorted = CommunitiesViewModel.sort(communities, by: .popular)

        #expect(sorted.map(\.id) == ["large", "medium", "small"])
    }

    @Test func popularUsesNameForEqualMemberCounts() {
        let communities = [
            community(id: "zulu", name: "zulu", memberCount: 10),
            community(id: "alpha", name: "Alpha", memberCount: 10)
        ]

        let sorted = CommunitiesViewModel.sort(communities, by: .popular)

        #expect(sorted.map(\.id) == ["alpha", "zulu"])
    }

    @Test func newestSortsByCreatedAtDescending() {
        let communities = [
            community(id: "old", name: "Old", createdAt: Date(timeIntervalSince1970: 10)),
            community(id: "new", name: "New", createdAt: Date(timeIntervalSince1970: 20))
        ]

        let sorted = CommunitiesViewModel.sort(communities, by: .newest)

        #expect(sorted.map(\.id) == ["new", "old"])
    }

    @Test func newestUsesNameForEqualCreatedAt() {
        let date = Date(timeIntervalSince1970: 20)
        let communities = [
            community(id: "zulu", name: "Zulu", createdAt: date),
            community(id: "alpha", name: "alpha", createdAt: date)
        ]

        let sorted = CommunitiesViewModel.sort(communities, by: .newest)

        #expect(sorted.map(\.id) == ["alpha", "zulu"])
    }

    @Test func newestPlacesMissingCreatedAtAfterDatedCommunities() {
        let communities = [
            community(id: "undated-zulu", name: "Zulu"),
            community(id: "dated", name: "Middle", createdAt: Date(timeIntervalSince1970: 20)),
            community(id: "undated-alpha", name: "Alpha")
        ]

        let sorted = CommunitiesViewModel.sort(communities, by: .newest)

        #expect(sorted.map(\.id) == ["dated", "undated-alpha", "undated-zulu"])
    }

    @Test func alphabeticalSortIsLocalizedAndCaseInsensitive() {
        let communities = [
            community(id: "zulu", name: "zulu"),
            community(id: "bravo", name: "Bravo"),
            community(id: "alpha", name: "alpha")
        ]

        let sorted = CommunitiesViewModel.sort(communities, by: .alphabetical)

        #expect(sorted.map(\.id) == ["alpha", "bravo", "zulu"])
    }

    @Test func searchAndCategoryFilterAreAppliedTogether() async {
        let repo = MockCommunityRepository()
        repo.communities = [
            community(id: "swift-art", name: "Swift Artists", interestTag: "Art"),
            community(id: "swift-tech", name: "Swift Developers", interestTag: "Tech"),
            community(id: "painting", name: "Painters", interestTag: "Art")
        ]
        let viewModel = CommunitiesViewModel(communityRepository: repo)
        await viewModel.loadCommunities()

        viewModel.searchQuery = "swift"
        viewModel.selectedInterestTag = "Art"

        #expect(viewModel.filteredCommunities.map(\.id) == ["swift-art"])
    }

    @Test func combinedFiltersCanReturnEmptyResult() async {
        let repo = MockCommunityRepository()
        repo.communities = [
            community(id: "swift-tech", name: "Swift Developers", interestTag: "Tech"),
            community(id: "painting", name: "Painters", interestTag: "Art")
        ]
        let viewModel = CommunitiesViewModel(communityRepository: repo)
        await viewModel.loadCommunities()

        viewModel.searchQuery = "swift"
        viewModel.selectedInterestTag = "Art"

        #expect(viewModel.filteredCommunities.isEmpty)
    }

    @Test func categoryFilterMatchesNormalizedChipValue() {
        let communities = [
            community(id: "art", name: "Artists", interestTag: " Art "),
            community(id: "tech", name: "Developers", interestTag: "Tech")
        ]

        let filtered = CommunitiesViewModel.filter(
            communities,
            searchQuery: "",
            selectedInterestTag: "art"
        )

        #expect(filtered.map(\.id) == ["art"])
    }

    @Test func createCommunityTrimsValidContentBeforeRepositoryBoundary() async {
        let repo = MockCommunityRepository()
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        let didCreate = await viewModel.createCommunity(
            name: "  Swift Circle \n",
            description: "\n Welcome  ",
            interestTag: "Swift"
        )

        #expect(didCreate)
        #expect(repo.createCallCount == 1)
        #expect(repo.lastCreatedName == "Swift Circle")
        #expect(repo.lastCreatedDescription == "Welcome")
    }

    @Test(arguments: [
        ("", "", "Enter a community name."),
        (String(repeating: "n", count: 31), "", "Name must be 30 characters or fewer."),
        ("Swift", String(repeating: "d", count: 501), "Description must be 500 characters or fewer.")
    ])
    func createCommunityRejectsInvalidContentBeforeRepository(
        name: String,
        description: String,
        expectedMessage: String
    ) async {
        let repo = MockCommunityRepository()
        let viewModel = CommunitiesViewModel(communityRepository: repo)

        let didCreate = await viewModel.createCommunity(
            name: name,
            description: description,
            interestTag: "Swift"
        )

        #expect(!didCreate)
        #expect(repo.createCallCount == 0)
        #expect(viewModel.createErrorMessage == expectedMessage)
    }

    @Test func createCommunityUploadsSelectedCover() async {
        let repo = MockCommunityRepository()
        let images = MockCommunityImageStorage()
        let viewModel = CommunitiesViewModel(communityRepository: repo, communityImageStorage: images)

        let didCreate = await viewModel.createCommunity(
            name: "Photo Circle", description: "Hello", interestTag: "Art", coverImage: validImageData
        )

        #expect(didCreate)
        #expect(repo.createCallCount == 1)
        #expect(images.uploadCoverCallCount == 1)
        #expect(repo.communities.last?.coverImageURL != nil)
    }

    @Test func failedCreateCoverCanRetryWithoutDuplicateCommunity() async {
        let repo = MockCommunityRepository()
        let images = MockCommunityImageStorage()
        images.uploadCoverError = CommunityFormTestError.failed
        let viewModel = CommunitiesViewModel(communityRepository: repo, communityImageStorage: images)

        let first = await viewModel.createCommunity(
            name: "Photo Circle", description: "Hello", interestTag: "Art", coverImage: validImageData
        )
        images.uploadCoverError = nil
        let retry = await viewModel.createCommunity(
            name: "Photo Circle", description: "Hello", interestTag: "Art", coverImage: validImageData
        )

        #expect(!first)
        #expect(retry)
        #expect(repo.createCallCount == 1)
        #expect(repo.updateMetadataCallCount == 1)
        #expect(images.uploadCoverCallCount == 2)
    }

    @Test func duplicateCreateIsIgnoredDuringCoverUpload() async {
        let repo = MockCommunityRepository()
        let images = MockCommunityImageStorage()
        images.shouldSuspendUpload = true
        let viewModel = CommunitiesViewModel(communityRepository: repo, communityImageStorage: images)

        let first = Task {
            await viewModel.createCommunity(
                name: "Photo Circle", description: "", interestTag: "Art", coverImage: validImageData
            )
        }
        while !images.hasPendingUpload { await Task.yield() }
        let duplicate = await viewModel.createCommunity(
            name: "Duplicate", description: "", interestTag: "Art", coverImage: nil
        )
        images.resumeUpload()

        #expect(!duplicate)
        #expect(await first.value)
        #expect(repo.createCallCount == 1)
    }

    private var validImageData: Data {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    private func community(
        id: String,
        name: String,
        description: String = "",
        interestTag: String = "General",
        memberCount: Int = 0,
        createdAt: Date? = nil
    ) -> Community {
        Community(
            id: id,
            name: name,
            description: description,
            interestTag: interestTag,
            memberCount: memberCount,
            createdAt: createdAt
        )
    }
}

private enum CommunityFormTestError: Error { case failed }
