import struct Auth.User
import Foundation
import Testing
@testable import Spread

/// Tests that `authManager.isLoading` is `true` while auth operations are in flight.
///
/// These tests validate the `isLoading` flag that drives the `ProgressView` overlay
/// in `LoginSheet` (sign-in), `SignUpSheet` (sign-up), and `ForgotPasswordSheet`
/// (password reset). View-layer overlay visibility is not directly testable without
/// ViewInspector; these tests confirm the underlying state that controls it.
@MainActor
struct LoadingOverlayTests {

    // MARK: - Suspending Mock

    /// An `AuthService` that suspends each operation until resumed explicitly.
    /// Allows tests to observe `isLoading` while an operation is in flight.
    private final class SuspendingAuthService: AuthService {
        var pendingSignIn: CheckedContinuation<AuthSuccess, Error>?
        var pendingSignUp: CheckedContinuation<AuthSuccess, Error>?
        var pendingResetPassword: CheckedContinuation<Void, Error>?

        func checkSession() async -> AuthSuccess? { nil }
        func signOut() async throws {}
        func handle(url: URL) async throws -> AuthDeepLinkResult { .recoverySession }
        func updatePassword(newPassword: String) async throws {}
        func resendVerification(email: String) async throws {}
        var authStateChanges: AsyncStream<AuthChangeEvent> { AsyncStream { _ in } }

        func signIn(email: String, password: String) async throws -> AuthSuccess {
            try await withCheckedThrowingContinuation { self.pendingSignIn = $0 }
        }

        func signUp(email: String, password: String) async throws -> AuthSuccess {
            try await withCheckedThrowingContinuation { self.pendingSignUp = $0 }
        }

        func resetPassword(email: String) async throws {
            try await withCheckedThrowingContinuation { self.pendingResetPassword = $0 }
        }
    }

    // MARK: - LoginSheet: isLoading during sign-in

    /// Conditions: `signIn` is called on `AuthManager` and the service has not yet resolved.
    /// Expected: `authManager.isLoading` is `true` while the operation is in flight and
    /// `false` once it completes — confirming the overlay appears and disappears correctly
    /// in `LoginSheet`.
    @Test func signInSetsIsLoadingWhileInFlight() async {
        let service = SuspendingAuthService()
        let authManager = AuthManager(service: service)

        let task = Task {
            try? await authManager.signIn(email: "test@example.com", password: "password123")
        }

        // Allow the task to start and suspend on the service continuation.
        for _ in 0..<10 { await Task.yield() }
        #expect(authManager.isLoading)

        service.pendingSignIn?.resume(throwing: URLError(.cancelled))
        await task.value
        #expect(!authManager.isLoading)
    }

    // MARK: - SignUpSheet: isLoading during sign-up

    /// Conditions: `signUp` is called on `AuthManager` and the service has not yet resolved.
    /// Expected: `authManager.isLoading` is `true` while in flight — confirming the overlay
    /// appears correctly in `SignUpSheet`.
    @Test func signUpSetsIsLoadingWhileInFlight() async {
        let service = SuspendingAuthService()
        let authManager = AuthManager(service: service)

        let task = Task {
            try? await authManager.signUp(email: "new@example.com", password: "password123")
        }

        for _ in 0..<10 { await Task.yield() }
        #expect(authManager.isLoading)

        service.pendingSignUp?.resume(throwing: URLError(.cancelled))
        await task.value
        #expect(!authManager.isLoading)
    }

    // MARK: - ForgotPasswordSheet: isLoading during password reset

    /// Conditions: `resetPassword` is called on `AuthManager` and the service has not yet resolved.
    /// Expected: `authManager.isLoading` is `true` while in flight — confirming the overlay
    /// appears correctly in `ForgotPasswordSheet`.
    @Test func resetPasswordSetsIsLoadingWhileInFlight() async {
        let service = SuspendingAuthService()
        let authManager = AuthManager(service: service)

        let task = Task {
            try? await authManager.resetPassword(email: "user@example.com")
        }

        for _ in 0..<10 { await Task.yield() }
        #expect(authManager.isLoading)

        service.pendingResetPassword?.resume(throwing: URLError(.cancelled))
        await task.value
        #expect(!authManager.isLoading)
    }

    // MARK: - isLoading clears on completion

    /// Conditions: `signIn` completes successfully.
    /// Expected: `authManager.isLoading` returns to `false` — overlay is dismissed.
    @Test func isLoadingFalseAfterSuccessfulOperation() async throws {
        let service = SuspendingAuthService()
        let authManager = AuthManager(service: service)

        let task = Task {
            try? await authManager.signIn(email: "test@example.com", password: "password123")
        }

        for _ in 0..<10 { await Task.yield() }

        let successResult = AuthSuccess(user: makeUser(email: "test@example.com"))
        service.pendingSignIn?.resume(returning: successResult)
        await task.value
        #expect(!authManager.isLoading)
    }

    // MARK: - Helpers

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
