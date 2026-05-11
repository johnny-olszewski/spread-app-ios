import Auth
import Foundation
import Testing
@testable import Spread

/// End-to-end smoke tests for all WKFLW-19 auth flows.
///
/// Each test exercises a complete user scenario using `MockAuthService` (success paths)
/// or a thin inline throwing adapter (failure paths). No network calls are made.
/// Flows requiring a real backend or live email inbox are documented in
/// `Documentation/ManualTests.md`.
@MainActor
struct AuthFlowTests {

    // MARK: - Helpers

    /// Builds a fake `Auth.AuthError.api` for the given error code and HTTP status.
    private func makeAPIError(
        code: Auth.ErrorCode,
        status: Int = 400
    ) -> Auth.AuthError {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.supabase.co")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        return .api(
            message: "error",
            errorCode: code,
            underlyingData: Data(),
            underlyingResponse: response
        )
    }

    /// An `AuthService` that succeeds for all methods except `signIn`, which throws.
    private final class FailingSignInService: AuthService {
        let error: Error
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { throw error }
        func signUp(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        func deleteAccount() async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// An `AuthService` that succeeds for all methods except `signUp`, which throws.
    private final class FailingSignUpService: AuthService {
        let error: Error
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess { throw error }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        func deleteAccount() async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// An `AuthService` that succeeds for all methods except `resetPassword`, which throws.
    private final class FailingResetPasswordService: AuthService {
        let error: Error
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func resetPassword(email: String) async throws { throw error }
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        func deleteAccount() async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// An `AuthService` that immediately emits a `.signedOut` event on `authStateChanges`.
    private final class SessionExpiryService: AuthService {
        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        func deleteAccount() async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> {
            AsyncStream { continuation in
                continuation.yield(.signedOut)
                continuation.finish()
            }
        }
    }

    // MARK: - Login: Success

    /// Conditions: User submits valid credentials via `AuthManager.signIn`.
    /// Expected: `state` transitions to `.signedIn` with the correct user and `onSignIn` is called.
    @Test func loginSuccessSignsInAndCallsCallback() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        var callbackEmail: String?
        authManager.onSignIn = { callbackEmail = $0.email }

        try await authManager.signIn(email: "user@example.com", password: "password123")

        #expect(authManager.state.isSignedIn)
        #expect(authManager.state.user?.email == "user@example.com")
        #expect(callbackEmail == "user@example.com")
        #expect(authManager.errorMessage == nil)
    }

    // MARK: - Login: Wrong Password

    /// Conditions: User submits incorrect credentials and the service throws `invalidCredentials`.
    /// Expected: `errorMessage` is "Invalid email or password." and state remains `.signedOut`.
    @Test func loginWrongPasswordShowsCredentialsError() async {
        let service = FailingSignInService(error: makeAPIError(code: .invalidCredentials))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "user@example.com", password: "wrongpass")

        #expect(!authManager.state.isSignedIn)
        #expect(authManager.errorMessage == "Invalid email or password.")
    }

    // MARK: - Login: Unconfirmed Email

    /// Conditions: User signs in before verifying their email; service throws `emailNotConfirmed`.
    /// Expected: `errorMessage` prompts the user to check their inbox.
    @Test func loginUnconfirmedEmailShowsVerifyMessage() async {
        let service = FailingSignInService(error: makeAPIError(code: .emailNotConfirmed))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "unverified@example.com", password: "password123")

        #expect(!authManager.state.isSignedIn)
        #expect(authManager.errorMessage == "Please verify your email first. Check your inbox.")
    }

    // MARK: - Sign-up: Success (Confirmation State)

    /// Conditions: User registers a new account; `MockAuthService.signUp` returns success.
    /// Expected: `AuthManager` does not transition to `.signedIn` and does not call `onSignIn`
    /// because email confirmation is required first. The view handles confirmation UI.
    @Test func signUpSuccessDoesNotSignInUntilEmailConfirmed() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        var onSignInCalled = false
        authManager.onSignIn = { _ in onSignInCalled = true }

        try await authManager.signUp(email: "new@example.com", password: "password123")

        #expect(!authManager.state.isSignedIn)
        #expect(!onSignInCalled)
        #expect(authManager.errorMessage == nil)
    }

    // MARK: - Sign-up: Duplicate Email

    /// Conditions: User registers with an email that already has an account;
    /// service throws `userAlreadyExists`.
    /// Expected: `errorMessage` tells the user an account already exists.
    @Test func signUpDuplicateEmailShowsAccountExistsError() async {
        let service = FailingSignUpService(error: makeAPIError(code: .userAlreadyExists))
        let authManager = AuthManager(service: service)

        try? await authManager.signUp(email: "existing@example.com", password: "password123")

        #expect(authManager.errorMessage == "An account with this email already exists.")
    }

    // MARK: - Forgot Password: Success

    /// Conditions: User requests a password reset for a valid email address.
    /// Expected: `resetPassword` completes without error and `errorMessage` remains nil.
    @Test func forgotPasswordSuccessClearsError() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)

        try await authManager.resetPassword(email: "user@example.com")

        #expect(authManager.errorMessage == nil)
        #expect(!authManager.isLoading)
    }

    // MARK: - Forgot Password: Failure

    /// Conditions: The password reset request fails (e.g., network error).
    /// Expected: `errorMessage` is set so the user knows the request did not go through.
    @Test func forgotPasswordFailureSetsErrorMessage() async {
        let service = FailingResetPasswordService(error: URLError(.notConnectedToInternet))
        let authManager = AuthManager(service: service)

        try? await authManager.resetPassword(email: "user@example.com")

        #expect(authManager.errorMessage != nil)
        #expect(!authManager.isLoading)
    }

    // MARK: - Password Update: Success

    /// Conditions: User follows a recovery deeplink, then successfully sets a new password.
    /// Expected: `updatePassword` succeeds, `clearRecoverySession` is called, and
    /// `coordinator.isRecoverySession` returns to `false`.
    @Test func passwordUpdateSuccessClearsRecoverySession() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)

        let recoveryURL = URL(string: "spread://auth/callback#access_token=abc&type=recovery")!
        await coordinator.handle(url: recoveryURL)
        #expect(coordinator.isRecoverySession)

        try await authManager.updatePassword(newPassword: "newSecurePass1!")
        coordinator.clearRecoverySession()

        #expect(!coordinator.isRecoverySession)
        #expect(authManager.errorMessage == nil)
    }

    // MARK: - Session Expiry

    /// Conditions: An external event (e.g., token revocation) causes the `authStateChanges`
    /// stream to emit `.signedOut` while the user is in the app.
    /// Expected: `AuthManager.state` transitions to `.signedOut` and `onSignOut` is called.
    @Test func sessionExpiryTransitionsToSignedOutAndCallsCallback() async {
        let service = SessionExpiryService()
        let authManager = AuthManager(service: service)
        var onSignOutCalled = false
        authManager.onSignOut = { onSignOutCalled = true }

        for _ in 0..<10 { await Task.yield() }

        #expect(!authManager.state.isSignedIn)
        #expect(onSignOutCalled)
    }

    // MARK: - Deeplink: Email Confirmation

    /// Conditions: The app receives a `type=signup` callback URL after the user taps the
    /// verification link in their email.
    /// Expected: `AuthDeepLinkCoordinator.isRecoverySession` remains `false` and
    /// `AuthManager` transitions to `.signedIn`.
    @Test func deeplinkEmailConfirmationSignsInWithoutRecoverySession() async {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)
        let url = URL(string: "spread://auth/callback#access_token=abc&type=signup")!

        await coordinator.handle(url: url)

        #expect(!coordinator.isRecoverySession)
        #expect(authManager.state.isSignedIn)
    }

    // MARK: - Deeplink: Password Recovery

    /// Conditions: The app receives a `type=recovery` callback URL after the user taps the
    /// reset-password link in their email.
    /// Expected: `AuthDeepLinkCoordinator.isRecoverySession` becomes `true`, which
    /// presents `SetNewPasswordSheet` in `ContentView`.
    @Test func deeplinkPasswordRecoverySetsRecoverySession() async {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        let coordinator = AuthDeepLinkCoordinator(service: service, authManager: authManager)
        let url = URL(string: "spread://auth/callback#access_token=abc&type=recovery")!

        await coordinator.handle(url: url)

        #expect(coordinator.isRecoverySession)
        #expect(!authManager.state.isSignedIn)
    }

    // MARK: - Delete Account

    /// An `AuthService` that delegates all operations to `MockAuthService` except
    /// `deleteAccount`, which throws the supplied error.
    private final class FailingDeleteAccountService: AuthService {
        let error: Error
        private let mock = MockAuthService()
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { await mock.checkSession() }
        func signIn(email: String, password: String) async throws -> AuthSuccess {
            try await mock.signIn(email: email, password: password)
        }
        func signUp(email: String, password: String) async throws -> AuthSuccess {
            try await mock.signUp(email: email, password: password)
        }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        func deleteAccount() async throws { throw error }
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// Conditions: `deleteAccount()` is called on `MockAuthService` (always succeeds).
    /// Expected: `AuthManager.state` transitions to `.signedOut`.
    @Test func deleteAccount_success_transitionsToSignedOut() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        // Sign in first to put the manager in a signed-in state.
        try await authManager.signIn(email: "user@example.com", password: "pass")
        #expect(authManager.state.isSignedIn)

        try await authManager.deleteAccount()

        #expect(!authManager.state.isSignedIn)
    }

    /// Conditions: `deleteAccount()` is called on `MockAuthService`.
    /// Expected: `onSignOut` callback is invoked after deletion.
    @Test func deleteAccount_success_callsOnSignOut() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)
        try await authManager.signIn(email: "user@example.com", password: "pass")
        var onSignOutCalled = false
        authManager.onSignOut = { onSignOutCalled = true }

        try await authManager.deleteAccount()

        #expect(onSignOutCalled)
    }

    /// Conditions: `deleteAccount()` throws a generic error.
    /// Expected: `authManager.errorMessage` is non-nil and `state` remains signed-in.
    @Test func deleteAccount_failure_setsErrorMessage() async throws {
        let deleteService = FailingDeleteAccountService(error: URLError(.notConnectedToInternet))
        let authManager = AuthManager(service: deleteService)
        // Sign in via the delegating mock to establish signed-in state.
        try await authManager.signIn(email: "user@example.com", password: "pass")
        #expect(authManager.state.isSignedIn)

        try? await authManager.deleteAccount()

        #expect(authManager.errorMessage != nil)
        #expect(authManager.state.isSignedIn)
    }

    // MARK: - Resend Verification: requiresEmailVerification state

    /// Conditions: Sign-in fails with `emailNotConfirmed`.
    /// Expected: `requiresEmailVerification` is `true` after the attempt.
    @Test func signInEmailNotConfirmed_setsRequiresEmailVerification() async {
        let service = FailingSignInService(error: makeAPIError(code: .emailNotConfirmed))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "unverified@example.com", password: "pass")

        #expect(authManager.requiresEmailVerification == true)
    }

    /// Conditions: Sign-in fails with `invalidCredentials` (wrong password), not `emailNotConfirmed`.
    /// Expected: `requiresEmailVerification` remains `false`.
    @Test func signInWrongPassword_doesNotSetRequiresEmailVerification() async {
        let service = FailingSignInService(error: makeAPIError(code: .invalidCredentials))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "user@example.com", password: "wrongpass")

        #expect(authManager.requiresEmailVerification == false)
    }

    /// Conditions: `requiresEmailVerification` was set by a prior failing sign-in;
    /// `clearError()` is called.
    /// Expected: `requiresEmailVerification` returns to `false`.
    @Test func clearError_clearsRequiresEmailVerification() async {
        let service = FailingSignInService(error: makeAPIError(code: .emailNotConfirmed))
        let authManager = AuthManager(service: service)
        try? await authManager.signIn(email: "unverified@example.com", password: "pass")
        #expect(authManager.requiresEmailVerification == true)

        authManager.clearError()

        #expect(authManager.requiresEmailVerification == false)
    }

    /// Conditions: `resendVerification` is called on `MockAuthService` (always succeeds).
    /// Expected: `errorMessage` is nil after the call (no error set on success).
    @Test func resendVerification_success_leavesNoError() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)

        try await authManager.resendVerification(email: "unverified@example.com")

        #expect(authManager.errorMessage == nil)
        #expect(!authManager.isLoading)
    }
}
