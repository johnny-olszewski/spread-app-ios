import Foundation
import Observation
import Supabase

/// Manages authentication state and operations.
///
/// Provides email/password sign-in, sign-out with confirmation,
/// and auth state observation for UI updates. Auth operations are
/// delegated to an injected `AuthService` to support different
/// implementations (Supabase, mock, debug).
@Observable
@MainActor
final class AuthManager {

    // MARK: - Auth State

    /// The current authentication state.
    enum AuthState: Equatable {
        /// User is not authenticated.
        case signedOut
        /// User is authenticated.
        case signedIn(User)

        /// Whether the user is currently signed in.
        var isSignedIn: Bool {
            if case .signedIn = self { return true }
            return false
        }

        /// The current user, if signed in.
        var user: User? {
            if case .signedIn(let user) = self { return user }
            return nil
        }
    }

    /// The current auth state.
    private(set) var state: AuthState = .signedOut

    /// Whether an auth operation is in progress.
    private(set) var isLoading = false

    /// The last error message, if any.
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    /// The service that performs auth operations.
    let service: AuthService

    /// Callback for when sign-out completes (to wipe local data).
    var onSignOut: (() async -> Void)?

    /// Callback for when sign-in completes (to start sync).
    var onSignIn: ((User) async -> Void)?

    /// Stored task observing `service.authStateChanges` for externally-triggered sign-outs.
    private var authStateObservationTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates an AuthManager with the specified auth service.
    ///
    /// - Parameter service: The service to delegate auth operations to.
    init(service: AuthService) {
        self.service = service

        Task {
            await checkSession()
        }

        authStateObservationTask = Task {
            await observeAuthStateChanges()
        }
    }

    // MARK: - Session Management

    /// Checks for an existing session on startup.
    private func checkSession() async {
        if let result = await service.checkSession() {
            state = .signedIn(result.user)
        } else {
            state = .signedOut
        }
    }

    /// Observes `service.authStateChanges` and transitions state on external sign-out events.
    ///
    /// Mirrors the manual sign-out path so `AuthLifecycleCoordinator` handles data wipe
    /// and sync reset automatically.
    private func observeAuthStateChanges() async {
        for await event in service.authStateChanges {
            switch event {
            case .signedOut:
                state = .signedOut
                await onSignOut?()
            }
        }
    }

    // MARK: - Sign In

    /// Signs in with email and password.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Throws: An error if sign-in fails.
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await service.signIn(email: email, password: password)

            state = .signedIn(result.user)

            await onSignIn?(result.user)

        } catch let error as ForcedAuthSignInError {
            errorMessage = error.forced.userMessage
            throw error
        } catch let error as AuthError {
            errorMessage = mapAuthError(error)
            throw error
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            throw error
        }
    }

    // MARK: - Sign Up

    /// Creates a new account with email and password.
    ///
    /// - Parameters:
    ///   - email: The new user's email address.
    ///   - password: The new user's password.
    /// - Throws: An error if sign-up fails.
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await service.signUp(email: email, password: password)

            state = .signedIn(result.user)

            await onSignIn?(result.user)

        } catch let error as ForcedAuthSignInError {
            errorMessage = error.forced.userMessage
            throw error
        } catch let error as AuthError {
            errorMessage = mapAuthError(error)
            throw error
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            throw error
        }
    }

    // MARK: - Reset Password

    /// Sends a password reset email.
    ///
    /// - Parameter email: The email address to send the reset link to.
    /// - Throws: An error if the request fails.
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await service.resetPassword(email: email)
        } catch let error as ForcedAuthSignInError {
            errorMessage = error.forced.userMessage
            throw error
        } catch {
            errorMessage = "Failed to send reset email. Please try again."
            throw error
        }
    }

    // MARK: - Update Password

    /// Updates the current signed-in user's password.
    ///
    /// - Parameter newPassword: The replacement password.
    /// - Throws: An error if the update fails.
    func updatePassword(newPassword: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await service.updatePassword(newPassword: newPassword)
        } catch let error as AuthError {
            errorMessage = mapAuthError(error)
            throw error
        } catch {
            errorMessage = "Failed to update password. Please try again."
            throw error
        }
    }

    // MARK: - Resend Verification

    /// Resends the verification email to the given address.
    ///
    /// On success no state change is needed — the user remains unconfirmed until they tap the link.
    ///
    /// - Parameter email: The email address to resend verification to.
    /// - Throws: An error if the request fails.
    func resendVerification(email: String) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await service.resendVerification(email: email)
        } catch {
            errorMessage = "Failed to resend verification email. Please try again."
            throw error
        }
    }

    // MARK: - Sign Out

    /// Signs out the current user.
    ///
    /// This will wipe local data via the `onSignOut` callback.
    func signOut() async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await service.signOut()
            state = .signedOut

            await onSignOut?()

        } catch {
            errorMessage = "Failed to sign out. Please try again."
            throw error
        }
    }

    // MARK: - Error Mapping

    /// Maps Supabase auth errors to user-friendly messages.
    private func mapAuthError(_ error: AuthError) -> String {
        switch error {
        case .api(_, let errorCode, _, _):
            switch errorCode {
            case .invalidCredentials:
                return "Invalid email or password."
            case .userNotFound:
                return "No account found with this email."
            case .sessionExpired, .sessionNotFound:
                return "Session expired. Please sign in again."
            default:
                return "Authentication failed. Please try again."
            }
        default:
            return "Authentication failed. Please try again."
        }
    }

    // MARK: - Helpers

    /// Clears any error message.
    func clearError() {
        errorMessage = nil
    }

    /// The current user's email, if signed in.
    var userEmail: String? {
        state.user?.email
    }

    // MARK: - Testing Support

    /// Updates auth state for tests without hitting the network.
    func setStateForTesting(_ state: AuthState) {
        self.state = state
    }

}
