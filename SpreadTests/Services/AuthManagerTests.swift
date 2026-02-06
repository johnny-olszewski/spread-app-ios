import struct Auth.User
import Foundation
import Testing
@testable import Spread

@MainActor
struct AuthManagerTests {

    // MARK: - Test Services

    /// Auth service that always succeeds with configurable results.
    private final class SuccessfulAuthService: AuthService {
        var hasBackupEntitlement = true
        var lastSignInEmail: String?

        func checkSession() async -> AuthSuccess? {
            nil
        }

        func signIn(email: String, password: String) async throws -> AuthSuccess {
            lastSignInEmail = email
            return AuthSuccess(
                user: makeUser(email: email),
                hasBackupEntitlement: hasBackupEntitlement
            )
        }

        func signOut() async throws {
            // Success
        }

        private func makeUser(email: String) -> User {
            let json = """
            {
                "id": "\(UUID().uuidString)",
                "email": "\(email)",
                "appMetadata": {},
                "userMetadata": {},
                "aud": "authenticated",
                "createdAt": "2024-01-01T00:00:00Z",
                "updatedAt": "2024-01-01T00:00:00Z"
            }
            """
            let data = json.data(using: .utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try! decoder.decode(User.self, from: data)
        }
    }

    /// Auth service that throws a configured error on sign-in.
    private final class FailingAuthService: AuthService {
        let error: Error

        init(error: Error) {
            self.error = error
        }

        func checkSession() async -> AuthSuccess? {
            nil
        }

        func signIn(email: String, password: String) async throws -> AuthSuccess {
            throw error
        }

        func signOut() async throws {
            // Success
        }
    }

    // MARK: - Sign In Success

    /// Conditions: Service returns success with backup entitlement.
    /// Expected: Auth succeeds, sets entitlement true, and calls onSignIn.
    @Test func signInSuccessSetsStateAndCallsCallback() async throws {
        let service = SuccessfulAuthService()
        service.hasBackupEntitlement = true

        let authManager = AuthManager(service: service)
        var callbackEmail: String?

        authManager.onSignIn = { user in
            callbackEmail = user.email
        }

        try await authManager.signIn(email: "test@example.com", password: "password")

        #expect(authManager.state.isSignedIn)
        #expect(authManager.hasBackupEntitlement)
        #expect(callbackEmail == "test@example.com")
    }

    /// Conditions: Service returns success without backup entitlement.
    /// Expected: Auth succeeds with entitlement false.
    @Test func signInSuccessWithoutEntitlement() async throws {
        let service = SuccessfulAuthService()
        service.hasBackupEntitlement = false

        let authManager = AuthManager(service: service)

        try await authManager.signIn(email: "test@example.com", password: "password")

        #expect(authManager.state.isSignedIn)
        #expect(!authManager.hasBackupEntitlement)
    }

    // MARK: - Forced Error

    /// Conditions: Service throws a forced auth error.
    /// Expected: Sign-in throws the forced error and sets a user-facing message.
    @Test func forcedErrorSetsUserMessage() async {
        let service = FailingAuthService(error: ForcedAuthSignInError(forced: .rateLimited))
        let authManager = AuthManager(service: service)

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

    // MARK: - Sign Out

    /// Conditions: User is signed in, sign-out succeeds.
    /// Expected: State becomes signedOut, entitlement false, callback called.
    @Test func signOutClearsStateAndCallsCallback() async throws {
        let service = SuccessfulAuthService()
        let authManager = AuthManager(service: service)
        var signOutCalled = false

        authManager.onSignOut = {
            signOutCalled = true
        }

        // Sign in first
        try await authManager.signIn(email: "test@example.com", password: "password")
        #expect(authManager.state.isSignedIn)

        // Sign out
        try await authManager.signOut()

        #expect(!authManager.state.isSignedIn)
        #expect(!authManager.hasBackupEntitlement)
        #expect(signOutCalled)
    }
}
