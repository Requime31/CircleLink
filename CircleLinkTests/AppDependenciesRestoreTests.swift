import Foundation
import Testing
@testable import CircleLink

@MainActor
struct AppDependenciesRestoreTests {
    @Test func restoreAuthenticatedProfileUsesAuthRepositoryProtocol() async throws {
        let auth = MockAuthRepository(currentUser: nil)
        auth.restoreSessionProfileResult = .success(MockAuthRepository.sampleUser)
        let dependencies = AppDependencies(authRepository: auth)

        let profile = try await dependencies.restoreAuthenticatedProfile()

        #expect(auth.restoreSessionProfileCallCount == 1)
        #expect(profile?.id == MockAuthRepository.sampleUser.id)
        #expect(auth.currentUser?.id == MockAuthRepository.sampleUser.id)
    }

    @Test func restoreAuthenticatedProfileReturnsNilWhenNoSession() async throws {
        let auth = MockAuthRepository(currentUser: nil)
        auth.restoreSessionProfileResult = .success(nil)
        let dependencies = AppDependencies(authRepository: auth)

        let profile = try await dependencies.restoreAuthenticatedProfile()

        #expect(auth.restoreSessionProfileCallCount == 1)
        #expect(profile == nil)
    }

    @Test func restoreAuthenticatedProfilePropagatesErrors() async {
        enum TestError: Error { case restoreFailed }

        let auth = MockAuthRepository()
        auth.restoreSessionProfileResult = .failure(TestError.restoreFailed)
        let dependencies = AppDependencies(authRepository: auth)

        await #expect(throws: TestError.self) {
            try await dependencies.restoreAuthenticatedProfile()
        }
        #expect(auth.restoreSessionProfileCallCount == 1)
    }
}
