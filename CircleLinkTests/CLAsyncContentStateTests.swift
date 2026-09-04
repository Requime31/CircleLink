import Testing
@testable import CircleLink

@MainActor
struct CLAsyncContentStateTests {
    @Test func onlyLoadingStateReportsLoading() {
        let states: [CLAsyncContentState<Int>] = [.idle, .loading, .content(1), .empty, .error("Offline")]
        #expect(states.map(\.isLoading) == [false, true, false, false, false])
    }

    @Test func equatableStateIncludesPayloadAndError() {
        #expect(CLAsyncContentState.content([1, 2]) == .content([1, 2]))
        #expect(CLAsyncContentState<String>.error("A") != .error("B"))
    }
}
