import struct Auth.User
import struct Foundation.UUID
import Testing
@testable import Spread

@MainActor
struct AuthManagerTests {

    private struct LocalhostPolicy: AuthPolicy {
        func forcedAuthError() -> ForcedAuthError? { nil }
        var isLocalhost: Bool { true }
    }

    private struct ForcedErrorPolicy: AuthPolicy {
        let forced: ForcedAuthError

        func forcedAuthError() -> ForcedAuthError? { forced }
        var isLocalhost: Bool { true }
    }

    // MARK: - Localhost Policy

    /// Conditions: Localhost policy is active for sign-in.
    /// Expected: Auth auto-succeeds, sets entitlement true, and calls onSignIn.
    @Test func localhostPolicyAutoSucceedsSignIn() async throws {
        let authManager = AuthManager(policy: LocalhostPolicy())
        var callbackEmail: String?

        authManager.onSignIn = { user in
            callbackEmail = user.email
        }

        try await authManager.signIn(email: "test@example.com", password: "password")

        #expect(authManager.state.isSignedIn)
        #expect(authManager.hasBackupEntitlement)
        #expect(callbackEmail == "test@example.com")
    }

    // MARK: - Forced Error Policy

    /// Conditions: Forced auth error policy is active.
    /// Expected: Sign-in throws the forced error and sets a user-facing message.
    @Test func forcedErrorPolicySetsUserMessage() async {
        let authManager = AuthManager(policy: ForcedErrorPolicy(forced: .rateLimited))

        do {
            try await authManager.signIn(email: "user@example.com", password: "password")
            #expect(false, "Expected forced auth error.")
        } catch let error as ForcedAuthSignInError {
            #expect(error.forced == .rateLimited)
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }

        #expect(authManager.errorMessage == ForcedAuthError.rateLimited.userMessage)
        #expect(!authManager.state.isSignedIn)
    }
}
