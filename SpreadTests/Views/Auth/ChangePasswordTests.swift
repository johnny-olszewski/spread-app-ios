import Foundation
import Testing
@testable import Spread

/// Unit tests for change-password flow (SPRD-210).
///
/// Covers `AuthManager.updatePassword` success/failure paths and
/// `AuthFormValidator` mismatch behavior that gates the form.
@MainActor
struct ChangePasswordTests {

    // MARK: - Helpers

    /// An `AuthService` that fails `updatePassword` with the supplied error.
    private final class FailingUpdatePasswordService: AuthService {
        let error: Error
        init(error: Error) { self.error = error }

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws { throw error }
        func resendVerification(email: String) async throws {}
        var authStateChanges: AsyncStream<Spread.AuthChangeEvent> { AsyncStream { _ in } }
    }

    // MARK: - Success

    /// Conditions: `updatePassword` succeeds via `MockAuthService`.
    /// Expected: `isLoading` returns to `false` and `errorMessage` is nil after the call.
    @Test func changePassword_success_clearsLoadingAndError() async throws {
        let service = MockAuthService()
        let authManager = AuthManager(service: service)

        try await authManager.updatePassword(newPassword: "NewSecure123!")

        #expect(!authManager.isLoading)
        #expect(authManager.errorMessage == nil)
    }

    // MARK: - Failure

    /// Conditions: `updatePassword` throws a generic error (e.g., network failure).
    /// Expected: `authManager.errorMessage` is non-nil after the failed attempt.
    @Test func changePassword_failure_setsErrorMessage() async {
        let service = FailingUpdatePasswordService(error: URLError(.notConnectedToInternet))
        let authManager = AuthManager(service: service)

        try? await authManager.updatePassword(newPassword: "NewSecure123!")

        #expect(authManager.errorMessage != nil)
        #expect(!authManager.isLoading)
    }

    // MARK: - Form Validation

    /// Conditions: New password and confirmation do not match.
    /// Expected: `AuthFormValidator.validatePasswordConfirmation` returns a non-nil error,
    /// so the form-valid gate would be `false`.
    @Test func changePassword_mismatch_failsValidation() {
        let error = AuthFormValidator.validatePasswordConfirmation(
            password: "Secure123!",
            confirmation: "Different123!"
        )
        #expect(error != nil)
    }

    /// Conditions: New password and confirmation are identical and meet length requirements.
    /// Expected: Both validators return nil, so the form is considered valid.
    @Test func changePassword_matching_passesValidation() {
        let passwordError = AuthFormValidator.validatePassword("Secure123!")
        let confirmError = AuthFormValidator.validatePasswordConfirmation(
            password: "Secure123!",
            confirmation: "Secure123!"
        )
        #expect(passwordError == nil)
        #expect(confirmError == nil)
    }

    // MARK: - Accessibility Identifiers

    /// Conditions: Accessibility identifiers are declared in `Definitions`.
    /// Expected: Each identifier is non-empty and unique.
    @Test func changePasswordIdentifiers_areNonEmptyAndUnique() {
        let ids = [
            Definitions.AccessibilityIdentifiers.ChangePasswordSheet.saveButton,
            Definitions.AccessibilityIdentifiers.ProfileSheet.changePasswordRow,
        ]
        for id in ids {
            #expect(!id.isEmpty)
        }
        #expect(Set(ids).count == ids.count)
    }
}
