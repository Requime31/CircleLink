import Foundation

/// Pure onboarding routing from a loaded profile.
/// Keeps age / profile-completeness rules out of AppCoordinator.
enum OnboardingRouteResolver {
    static func route(for user: User) -> AppCoordinator.Route {
        if user.ageConfirmedAt == nil {
            return .ageGate
        }
        if !user.isProfileComplete {
            return .profileSetup
        }
        return .mainTab
    }
}
