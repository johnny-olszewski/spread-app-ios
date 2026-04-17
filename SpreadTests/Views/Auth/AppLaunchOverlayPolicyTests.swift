import Foundation
import Testing
@testable import Spread

struct AppLaunchOverlayPolicyTests {

    /// Conditions: Product environment requires auth and user is signed out.
    /// Expected: The blocking auth gate overlay is shown.
    @Test func signedOutProductEnvironmentShowsAuthGate() {
        let overlay = AppLaunchOverlayPolicy.overlay(
            environment: .development,
            isSignedIn: false,
            hasCompletedOnboarding: false
        )

        #expect(overlay == .authGate)
    }

    /// Conditions: Product environment user is signed in but onboarding is incomplete.
    /// Expected: Onboarding is shown after authentication.
    @Test func signedInWithoutOnboardingShowsOnboarding() {
        let overlay = AppLaunchOverlayPolicy.overlay(
            environment: .production,
            isSignedIn: true,
            hasCompletedOnboarding: false
        )

        #expect(overlay == .onboarding)
    }

    /// Conditions: Product environment user is signed in and onboarding is complete.
    /// Expected: No launch overlay is needed.
    @Test func completedOnboardingClearsLaunchOverlay() {
        let overlay = AppLaunchOverlayPolicy.overlay(
            environment: .development,
            isSignedIn: true,
            hasCompletedOnboarding: true
        )

        #expect(overlay == .none)
    }

    /// Conditions: Debug localhost mode does not require auth.
    /// Expected: No auth gate or onboarding overlay is shown.
    @Test func localhostBypassesLaunchOverlays() {
        let overlay = AppLaunchOverlayPolicy.overlay(
            environment: .localhost,
            isSignedIn: false,
            hasCompletedOnboarding: false
        )

        #expect(overlay == .none)
    }
}
