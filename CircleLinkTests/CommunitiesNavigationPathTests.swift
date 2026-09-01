import Testing
@testable import CircleLink

@MainActor
struct CommunitiesNavigationPathTests {
    @Test func rootToDetailAddsOnlyDetail() {
        let detail = CommunitiesRoute.communityDetail(id: "swift", name: "Swift")

        let path = CommunitiesNavigationPathPolicy.appending(detail, to: [])

        #expect(path == [detail])
    }

    @Test func rootToAllPopularAddsPopularCatalog() {
        let all = CommunitiesRoute.allCommunities(sortOrder: .popular)

        let path = CommunitiesNavigationPathPolicy.appending(all, to: [])

        #expect(path == [all])
    }

    @Test func rootToAllNewestAddsNewestCatalog() {
        let all = CommunitiesRoute.allCommunities(sortOrder: .newest)

        let path = CommunitiesNavigationPathPolicy.appending(all, to: [])

        #expect(path == [all])
    }

    @Test func allToDetailAndBackKeepsPredictableHierarchy() {
        let all = CommunitiesRoute.allCommunities(sortOrder: .popular)
        let detail = CommunitiesRoute.communityDetail(id: "swift", name: "Swift")
        var path = CommunitiesNavigationPathPolicy.appending(all, to: [])
        path = CommunitiesNavigationPathPolicy.appending(detail, to: path)

        #expect(path == [all, detail])

        path.removeLast()
        #expect(path == [all])

        path.removeLast()
        #expect(path.isEmpty)
    }

    @Test func repeatedAllDestinationIsNotAppended() {
        let all = CommunitiesRoute.allCommunities(sortOrder: .popular)

        let path = CommunitiesNavigationPathPolicy.appending(all, to: [all])

        #expect(path == [all])
    }

    @Test func allSortVariantsShareCatalogIdentity() {
        let popular = CommunitiesRoute.allCommunities(sortOrder: .popular)
        let newest = CommunitiesRoute.allCommunities(sortOrder: .newest)

        let path = CommunitiesNavigationPathPolicy.appending(newest, to: [popular])

        #expect(path == [popular])
    }

    @Test func repeatedDetailWithSameIDIsNotAppended() {
        let detail = CommunitiesRoute.communityDetail(id: "swift", name: "Swift")
        let sameIDWithRefreshedName = CommunitiesRoute.communityDetail(
            id: "swift",
            name: "Swift Community"
        )

        let path = CommunitiesNavigationPathPolicy.appending(sameIDWithRefreshedName, to: [detail])

        #expect(path == [detail])
    }

    @Test func differentDetailIDsAreDistinctDestinations() {
        let first = CommunitiesRoute.communityDetail(id: "swift", name: "Swift")
        let second = CommunitiesRoute.communityDetail(id: "ios", name: "iOS")
        var path = CommunitiesNavigationPathPolicy.appending(first, to: [])
        path = CommunitiesNavigationPathPolicy.appending(second, to: path)

        #expect(path == [first, second])
    }
}
