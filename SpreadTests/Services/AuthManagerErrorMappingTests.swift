import Auth
import struct Auth.User
import Foundation
import Testing
@testable import Spread

/// Tests for expanded `AuthManager` error message mapping (SPRD-206).
///
/// Verifies that each new Supabase `AuthError` code and network errors produce
/// the correct user-facing message. Also confirms `signUp` no longer transitions
/// to `signedIn` state on success (email confirmation is required first).
@MainActor
struct AuthManagerErrorMappingTests {

    // MARK: - Helpers

    /// Builds a fake `Auth.AuthError.api` for the given error code.
    private func makeAPIError(code: Auth.ErrorCode) -> Auth.AuthError {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.supabase.co")!,
            statusCode: 400,
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

    /// An `AuthService` whose `signIn` throws the given error.
    private final class ThrowingSignInService: AuthService {
        let error: Error
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { throw error }
        func signUp(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func resetPassword(email: String) async throws { fatalError("not used") }
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// An `AuthService` whose `signUp` throws the given error.
    private final class ThrowingSignUpService: AuthService {
        let error: Error
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess { throw error }
        func resetPassword(email: String) async throws { fatalError("not used") }
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// An `AuthService` whose `resetPassword` throws the given error.
    private final class ThrowingResetService: AuthService {
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
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    /// A no-op `AuthService` whose `signUp` always succeeds.
    private final class SuccessfulSignUpService: AuthService {
        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess {
            AuthSuccess(user: makeUser(email: email))
        }
        func resetPassword(email: String) async throws { fatalError("not used") }
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }

        private func makeUser(email: String) -> Auth.User {
            let json = """
            {
                "id": "11111111-1111-1111-1111-111111111111",
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
            return try! decoder.decode(Auth.User.self, from: data)
        }
    }

    // MARK: - emailNotConfirmed

    /// Conditions: `signIn` fails with `AuthErrorCode.emailNotConfirmed`.
    /// Expected: `errorMessage` is "Please verify your email first. Check your inbox."
    @Test func emailNotConfirmedProducesVerifyEmailMessage() async throws {
        let service = ThrowingSignInService(error: makeAPIError(code: Auth.ErrorCode.emailNotConfirmed))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "user@example.com", password: "password123")

        #expect(authManager.errorMessage == "Please verify your email first. Check your inbox.")
    }

    // MARK: - userAlreadyExists

    /// Conditions: `signUp` fails with `AuthErrorCode.userAlreadyExists`.
    /// Expected: `errorMessage` is "An account with this email already exists."
    @Test func userAlreadyExistsProducesDuplicateAccountMessage() async throws {
        let service = ThrowingSignUpService(error: makeAPIError(code: Auth.ErrorCode.userAlreadyExists))
        let authManager = AuthManager(service: service)

        try? await authManager.signUp(email: "existing@example.com", password: "password123")

        #expect(authManager.errorMessage == "An account with this email already exists.")
    }

    /// Conditions: `signUp` fails with `AuthErrorCode.emailExists`.
    /// Expected: `errorMessage` is "An account with this email already exists."
    @Test func emailExistsProducesDuplicateAccountMessage() async throws {
        let service = ThrowingSignUpService(error: makeAPIError(code: Auth.ErrorCode.emailExists))
        let authManager = AuthManager(service: service)

        try? await authManager.signUp(email: "existing@example.com", password: "password123")

        #expect(authManager.errorMessage == "An account with this email already exists.")
    }

    // MARK: - Rate Limiting

    /// Conditions: `signIn` fails with `AuthErrorCode.overRequestRateLimit`.
    /// Expected: `errorMessage` is "Too many attempts. Please try again later."
    @Test func overRequestRateLimitProducesTooManyAttemptsMessage() async throws {
        let service = ThrowingSignInService(error: makeAPIError(code: Auth.ErrorCode.overRequestRateLimit))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "user@example.com", password: "password123")

        #expect(authManager.errorMessage == "Too many attempts. Please try again later.")
    }

    /// Conditions: `resetPassword` fails with `AuthErrorCode.overEmailSendRateLimit`.
    /// Expected: `errorMessage` is "Too many attempts. Please try again later."
    @Test func overEmailSendRateLimitProducesTooManyAttemptsMessage() async throws {
        let service = ThrowingResetService(error: makeAPIError(code: Auth.ErrorCode.overEmailSendRateLimit))
        let authManager = AuthManager(service: service)

        try? await authManager.resetPassword(email: "user@example.com")

        #expect(authManager.errorMessage == "Too many attempts. Please try again later.")
    }

    // MARK: - Network Errors

    /// Conditions: `signIn` fails with a `URLError`.
    /// Expected: `errorMessage` is "No internet connection. Please check your network and try again."
    @Test func signInURLErrorProducesNoInternetMessage() async throws {
        let service = ThrowingSignInService(error: URLError(.notConnectedToInternet))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "user@example.com", password: "password123")

        #expect(authManager.errorMessage == "No internet connection. Please check your network and try again.")
    }

    /// Conditions: `signUp` fails with a `URLError`.
    /// Expected: `errorMessage` is "No internet connection. Please check your network and try again."
    @Test func signUpURLErrorProducesNoInternetMessage() async throws {
        let service = ThrowingSignUpService(error: URLError(.notConnectedToInternet))
        let authManager = AuthManager(service: service)

        try? await authManager.signUp(email: "new@example.com", password: "password123")

        #expect(authManager.errorMessage == "No internet connection. Please check your network and try again.")
    }

    /// Conditions: `resetPassword` fails with a `URLError`.
    /// Expected: `errorMessage` is "No internet connection. Please check your network and try again."
    @Test func resetPasswordURLErrorProducesNoInternetMessage() async throws {
        let service = ThrowingResetService(error: URLError(.notConnectedToInternet))
        let authManager = AuthManager(service: service)

        try? await authManager.resetPassword(email: "user@example.com")

        #expect(authManager.errorMessage == "No internet connection. Please check your network and try again.")
    }

    // MARK: - signUp Does Not Auto-Sign-In

    /// Conditions: `signUp` succeeds.
    /// Expected: `authManager.state` remains `.signedOut` — email confirmation is required
    /// before the user is signed in. `SignUpSheet` handles the confirmation UI.
    @Test func successfulSignUpDoesNotTransitionToSignedIn() async throws {
        let service = SuccessfulSignUpService()
        let authManager = AuthManager(service: service)

        try await authManager.signUp(email: "new@example.com", password: "password123")

        #expect(!authManager.state.isSignedIn)
        #expect(authManager.errorMessage == nil)
    }

    // MARK: - Existing Error Messages Preserved

    /// Conditions: `signIn` fails with `AuthErrorCode.invalidCredentials`.
    /// Expected: `errorMessage` is still "Invalid email or password."
    @Test func invalidCredentialsMessagePreserved() async throws {
        let service = ThrowingSignInService(error: makeAPIError(code: Auth.ErrorCode.invalidCredentials))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "user@example.com", password: "wrong")

        #expect(authManager.errorMessage == "Invalid email or password.")
    }

    /// Conditions: `signIn` fails with `AuthErrorCode.userNotFound`.
    /// Expected: `errorMessage` is still "No account found with this email."
    @Test func userNotFoundMessagePreserved() async throws {
        let service = ThrowingSignInService(error: makeAPIError(code: Auth.ErrorCode.userNotFound))
        let authManager = AuthManager(service: service)

        try? await authManager.signIn(email: "nobody@example.com", password: "password123")

        #expect(authManager.errorMessage == "No account found with this email.")
    }
}
