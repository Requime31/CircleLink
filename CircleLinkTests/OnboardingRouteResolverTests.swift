import Foundation
import Testing
@testable import CircleLink

struct OnboardingRouteResolverTests {
    @Test func routesToAgeGateWhenAgeNotConfirmed() {
        let user = makeUser(ageConfirmedAt: nil, displayName: "Ada", interests: ["a", "b", "c"])
        #expect(OnboardingRouteResolver.route(for: user) == .ageGate)
    }

    @Test func routesToProfileSetupWhenProfileIncomplete() {
        let user = makeUser(ageConfirmedAt: Date(), displayName: "", interests: [])
        #expect(OnboardingRouteResolver.route(for: user) == .profileSetup)
    }

    @Test func routesToMainTabWhenOnboardingComplete() {
        let user = makeUser(
            ageConfirmedAt: Date(),
            displayName: "Ada",
            interests: ["Swift", "Design", "Music"]
        )
        #expect(OnboardingRouteResolver.route(for: user) == .mainTab)
    }

    private func makeUser(
        ageConfirmedAt: Date?,
        displayName: String,
        interests: [String]
    ) -> User {
        User(
            id: "u1",
            displayName: displayName,
            avatarURL: nil,
            avatarBase64: nil,
            interests: interests,
            ageConfirmedAt: ageConfirmedAt
        )
    }
}
