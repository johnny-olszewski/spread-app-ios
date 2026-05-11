import struct Auth.User
import Foundation
import Testing
@testable import Spread

/// Tests for the sign-up email confirmation flow driven at the AuthManager layer.
///
/// The `submittedEmail` state in `SignUpSheet` is `@State private` and cannot be
/// asserted directly. These tests verify the AuthManager behaviors that the view
/// depends on: `signUp` can succeed, `resendVerification` can succeed, and
/// `resendVerification` failure surfaces an error message.
@MainActor
struct SignUpConfirmationTests {

    // MARK: - Helpers

    private final class TrackingAuthService: AuthService {
        var resendCalledWith: String?
        var shouldFailResend = false

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess {
            AuthSuccess(user: makeUser(email: email))
        }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func deleteAccount() async throws {}
        func resendVerification(email: String) async throws {
            resendCalledWith = email
            if shouldFailResend { throw URLError(.notConnectedToInternet) }
        }
        var authStateChanges: AsyncStream<AuthChangeEvent> { AsyncStream { _ in } }

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

    // MARK: - Sign-Up Success

    /// Conditions: `signUp` is called with valid credentials and the service succeeds.
    /// Expected: No error is thrown — the view can safely set `submittedEmail`.
    @Test func signUpSuccessDoesNotThrow() async throws {
        let service = TrackingAuthService()
        let authManager = AuthManager(service: service)

        try await authManager.signUp(email: "user@example.com", password: "password123")

        #expect(authManager.errorMessage == nil)
        #expect(!authManager.isLoading)
    }

    // MARK: - Resend Verification

    /// Conditions: `resendVerification` is called with the submitted email.
    /// Expected: The service receives the correct email and no error is set.
    @Test func resendVerificationForwardsEmailToService() async throws {
        let service = TrackingAuthService()
        let authManager = AuthManager(service: service)

        try await authManager.resendVerification(email: "user@example.com")

        #expect(service.resendCalledWith == "user@example.com")
        #expect(authManager.errorMessage == nil)
    }

    /// Conditions: `resendVerification` fails (e.g., network error).
    /// Expected: `errorMessage` is set so the view can surface it below the Resend button.
    @Test func resendVerificationFailureSetsErrorMessageForView() async {
        let service = TrackingAuthService()
        service.shouldFailResend = true
        let authManager = AuthManager(service: service)

        do {
            try await authManager.resendVerification(email: "user@example.com")
            #expect(Bool(false), "Expected error.")
        } catch {
            // Expected
        }

        #expect(authManager.errorMessage != nil)
        #expect(!authManager.isLoading)
    }
}
