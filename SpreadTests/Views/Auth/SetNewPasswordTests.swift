import struct Auth.User
import Foundation
import Testing
@testable import Spread

/// Tests for the SetNewPasswordSheet flow driven at the coordinator and AuthManager layer.
///
/// View-level state (field values, dismiss) cannot be unit-tested without ViewInspector.
/// These tests verify the coordinator and auth manager behaviors that the sheet depends on.
@MainActor
struct SetNewPasswordTests {

    // MARK: - Helpers

    private final class TrackingUpdateService: AuthService {
        var updatePasswordCalled = false
        var shouldFail = false

        func checkSession() async -> AuthSuccess? { nil }
        func signIn(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func signUp(email: String, password: String) async throws -> AuthSuccess { fatalError("not used") }
        func resetPassword(email: String) async throws {}
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {
            updatePasswordCalled = true
            if shouldFail { throw URLError(.notConnectedToInternet) }
        }
        func resendVerification(email: String) async throws {}
        var authStateChanges: AsyncStream<AuthChangeEvent> { AsyncStream { _ in } }
    }

    private func makeCoordinator(
        service: AuthService? = nil
    ) -> (coordinator: AuthDeepLinkCoordinator, authManager: AuthManager, service: TrackingUpdateService) {
        let svc = TrackingUpdateService()
        let authManager = AuthManager(service: service ?? svc)
        let coordinator = AuthDeepLinkCoordinator(service: service ?? svc, authManager: authManager)
        return (coordinator, authManager, svc)
    }

    // MARK: - Successful Save

    /// Conditions: `updatePassword` succeeds and `clearRecoverySession` is called.
    /// Expected: `isRecoverySession` becomes `false` (sheet will be dismissed by the binding).
    @Test func successfulUpdatePasswordClearsRecoverySession() async throws {
        let svc = TrackingUpdateService()
        let authManager = AuthManager(service: svc)
        let coordinator = AuthDeepLinkCoordinator(service: svc, authManager: authManager)

        // Simulate the recovery session being active
        let recoveryURL = URL(string: "spread://auth/callback#type=recovery")!
        await coordinator.handle(url: recoveryURL)
        #expect(coordinator.isRecoverySession)

        // Simulate the save button action
        try await authManager.updatePassword(newPassword: "newSecure1!")
        coordinator.clearRecoverySession()

        #expect(!coordinator.isRecoverySession)
        #expect(svc.updatePasswordCalled)
    }

    // MARK: - Cancel

    /// Conditions: The user taps Cancel — `clearRecoverySession` is called without calling `updatePassword`.
    /// Expected: `isRecoverySession` becomes `false` and `updatePassword` is never invoked.
    @Test func cancelClearsRecoverySessionWithoutCallingUpdatePassword() async {
        let svc = TrackingUpdateService()
        let authManager = AuthManager(service: svc)
        let coordinator = AuthDeepLinkCoordinator(service: svc, authManager: authManager)

        let recoveryURL = URL(string: "spread://auth/callback#type=recovery")!
        await coordinator.handle(url: recoveryURL)
        #expect(coordinator.isRecoverySession)

        // Simulate cancel action
        coordinator.clearRecoverySession()

        #expect(!coordinator.isRecoverySession)
        #expect(!svc.updatePasswordCalled)
    }

    // MARK: - Form Validation

    /// Conditions: Password field is empty.
    /// Expected: `AuthFormValidator.validatePassword` returns a non-nil error — Save button stays disabled.
    @Test func emptyPasswordFailsValidation() {
        let error = AuthFormValidator.validatePassword("")
        #expect(error != nil)
    }

    /// Conditions: Password is valid but confirm password is empty.
    /// Expected: `validatePasswordConfirmation` returns a non-nil error — Save button stays disabled.
    @Test func emptyConfirmPasswordFailsValidation() {
        let error = AuthFormValidator.validatePasswordConfirmation(
            password: "valid123",
            confirmation: ""
        )
        #expect(error != nil)
    }

    /// Conditions: Password and confirm password do not match.
    /// Expected: `validatePasswordConfirmation` returns a non-nil error — Save button stays disabled.
    @Test func mismatchedPasswordsFailValidation() {
        let error = AuthFormValidator.validatePasswordConfirmation(
            password: "valid123",
            confirmation: "different456"
        )
        #expect(error != nil)
    }

    /// Conditions: Password and confirm password are both valid and match.
    /// Expected: Both validators return nil — Save button is enabled.
    @Test func matchingValidPasswordsPassValidation() {
        let passwordError = AuthFormValidator.validatePassword("valid123")
        let confirmError = AuthFormValidator.validatePasswordConfirmation(
            password: "valid123",
            confirmation: "valid123"
        )
        #expect(passwordError == nil)
        #expect(confirmError == nil)
    }
}
