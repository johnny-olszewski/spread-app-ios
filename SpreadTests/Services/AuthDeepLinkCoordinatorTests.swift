import Foundation
import Testing
@testable import Spread

@MainActor
struct AuthDeepLinkCoordinatorTests {

    // MARK: - Recovery Session

    /// Conditions: A `type=recovery` deeplink URL is handled.
    /// Expected: `isRecoverySession` is set to `true`.
    @Test func handleRecoveryURLSetsIsRecoverySession() async {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)
        let url = URL(string: "spread://auth/callback#access_token=abc&type=recovery")!

        await coordinator.handle(url: url)

        #expect(coordinator.isRecoverySession)
    }

    /// Conditions: `clearRecoverySession()` is called after a recovery deeplink was handled.
    /// Expected: `isRecoverySession` returns to `false`.
    @Test func clearRecoverySessionResetsState() async {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)
        let url = URL(string: "spread://auth/callback#access_token=abc&type=recovery")!

        await coordinator.handle(url: url)
        #expect(coordinator.isRecoverySession)

        coordinator.clearRecoverySession()
        #expect(!coordinator.isRecoverySession)
    }

    // MARK: - Email Confirmed

    /// Conditions: A `type=signup` deeplink URL is handled.
    /// Expected: `isRecoverySession` remains `false`.
    @Test func handleEmailConfirmedURLDoesNotSetIsRecoverySession() async {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)
        let url = URL(string: "spread://auth/callback#access_token=abc&type=signup")!

        await coordinator.handle(url: url)

        #expect(!coordinator.isRecoverySession)
    }

    /// Conditions: A `type=signup` deeplink URL is handled with a MockAuthService.
    /// Expected: `AuthManager.state` transitions to `.signedIn`.
    @Test func handleEmailConfirmedURLSignsInAuthManager() async {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)
        let url = URL(string: "spread://auth/callback#access_token=abc&type=signup")!

        await coordinator.handle(url: url)

        #expect(authManager.state.isSignedIn)
    }
}
