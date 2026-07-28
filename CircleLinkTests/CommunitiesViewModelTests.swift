import Foundation
import Testing
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
}
