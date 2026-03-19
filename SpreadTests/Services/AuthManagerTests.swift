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
        var lastSignUpEmail: String?
        var lastResetEmail: String?

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

        func signUp(email: String, password: String) async throws -> AuthSuccess {
            lastSignUpEmail = email
            return AuthSuccess(
                user: makeUser(email: email),
                hasBackupEntitlement: hasBackupEntitlement
            )
        }

        func resetPassword(email: String) async throws {
            lastResetEmail = email
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

    /// Auth service that throws a configured error on sign-in/sign-up.
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

        func signUp(email: String, password: String) async throws -> AuthSuccess {
            throw error
        }

        func resetPassword(email: String) async throws {
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

    // MARK: - Sign Up

    /// Conditions: Service returns success for sign-up.
    /// Expected: Auth succeeds, state is signed in, and onSignIn callback is called.
    @Test func signUpSuccessSetsStateAndCallsCallback() async throws {
        let service = SuccessfulAuthService()
        let authManager = AuthManager(service: service)
        var callbackEmail: String?

        authManager.onSignIn = { user in
            callbackEmail = user.email
        }

        try await authManager.signUp(email: "new@example.com", password: "password123")

        #expect(authManager.state.isSignedIn)
        #expect(callbackEmail == "new@example.com")
        #expect(service.lastSignUpEmail == "new@example.com")
    }

    /// Conditions: Service throws a forced error on sign-up.
    /// Expected: Sign-up throws the forced error and sets a user-facing message.
    @Test func signUpForcedErrorSetsUserMessage() async {
        let service = FailingAuthService(error: ForcedAuthSignInError(forced: .networkTimeout))
        let authManager = AuthManager(service: service)

        do {
            try await authManager.signUp(email: "new@example.com", password: "password123")
            #expect(false, "Expected forced auth error.")
        } catch is ForcedAuthSignInError {
            // Expected
        } catch {
            #expect(false, "Unexpected error: \(error)")
        }

        #expect(authManager.errorMessage == ForcedAuthError.networkTimeout.userMessage)
        #expect(!authManager.state.isSignedIn)
    }

    // MARK: - Reset Password

    /// Conditions: Service succeeds for reset password.
    /// Expected: No error message is set, isLoading returns to false.
    @Test func resetPasswordSuccessNoError() async throws {
        let service = SuccessfulAuthService()
        let authManager = AuthManager(service: service)

        try await authManager.resetPassword(email: "user@example.com")

        #expect(authManager.errorMessage == nil)
        #expect(!authManager.isLoading)
        #expect(service.lastResetEmail == "user@example.com")
    }

    /// Conditions: Service throws on reset password.
    /// Expected: Error message is set.
    @Test func resetPasswordFailureSetsErrorMessage() async {
        let service = FailingAuthService(error: ForcedAuthSignInError(forced: .networkTimeout))
        let authManager = AuthManager(service: service)

        do {
            try await authManager.resetPassword(email: "user@example.com")
            #expect(false, "Expected error.")
        } catch {
            // Expected
        }

        #expect(authManager.errorMessage == ForcedAuthError.networkTimeout.userMessage)
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
