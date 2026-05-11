import Foundation
import OSLog
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

    /// Whether the last sign-in attempt failed because the email is not yet confirmed.
    ///
    /// Set to `true` when sign-in returns an `emailNotConfirmed` error.
    /// Reset to `false` on any other sign-in outcome, on `clearError()`, and on sign-out.
    private(set) var requiresEmailVerification = false

    // MARK: - Logging

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "AuthManager")

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
        requiresEmailVerification = false

        defer { isLoading = false }

        let email = email.trimmingCharacters(in: .whitespaces)
        Self.logger.info("signIn: attempting for \(email, privacy: .private)")

        do {
            let result = try await service.signIn(email: email, password: password)

            state = .signedIn(result.user)
            Self.logger.info("signIn: succeeded for \(email, privacy: .private)")

            await onSignIn?(result.user)

        } catch let error as ForcedAuthSignInError {
            Self.logger.warning("signIn: forced error — \(error.forced.userMessage)")
            errorMessage = error.forced.userMessage
            throw error
        } catch let error as AuthError {
            Self.logger.error("signIn: AuthError — \(String(describing: error))")
            if case .api(_, let errorCode, _, _) = error, errorCode == .emailNotConfirmed {
                requiresEmailVerification = true
            }
            errorMessage = mapAuthError(error)
            throw error
        } catch let error as URLError {
            Self.logger.error("signIn: URLError \(error.code.rawValue) — \(error.localizedDescription)")
            errorMessage = "No internet connection. Please check your network and try again."
            throw error
        } catch {
            Self.logger.error("signIn: unexpected error — \(error)")
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

        let email = email.trimmingCharacters(in: .whitespaces)
        Self.logger.info("signUp: attempting for \(email, privacy: .private)")

        do {
            // Sign-up always requires email verification; state transitions to signedIn
            // only after the user taps the confirmation link (handled via deeplink).
            _ = try await service.signUp(email: email, password: password)
            Self.logger.info("signUp: succeeded for \(email, privacy: .private) — awaiting email confirmation")

        } catch let error as ForcedAuthSignInError {
            Self.logger.warning("signUp: forced error — \(error.forced.userMessage)")
            errorMessage = error.forced.userMessage
            throw error
        } catch let error as AuthError {
            Self.logger.error("signUp: AuthError — \(String(describing: error))")
            errorMessage = mapAuthError(error)
            throw error
        } catch let error as URLError {
            Self.logger.error("signUp: URLError \(error.code.rawValue) — \(error.localizedDescription)")
            errorMessage = "No internet connection. Please check your network and try again."
            throw error
        } catch {
            Self.logger.error("signUp: unexpected error — \(error)")
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

        let email = email.trimmingCharacters(in: .whitespaces)
        Self.logger.info("resetPassword: requesting for \(email, privacy: .private)")

        do {
            try await service.resetPassword(email: email)
            Self.logger.info("resetPassword: succeeded for \(email, privacy: .private)")
        } catch let error as ForcedAuthSignInError {
            Self.logger.warning("resetPassword: forced error — \(error.forced.userMessage)")
            errorMessage = error.forced.userMessage
            throw error
        } catch let error as AuthError {
            Self.logger.error("resetPassword: AuthError — \(String(describing: error))")
            errorMessage = mapAuthError(error)
            throw error
        } catch let error as URLError {
            Self.logger.error("resetPassword: URLError \(error.code.rawValue) — \(error.localizedDescription)")
            errorMessage = "No internet connection. Please check your network and try again."
            throw error
        } catch {
            Self.logger.error("resetPassword: unexpected error — \(error)")
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

        let email = email.trimmingCharacters(in: .whitespaces)

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

    // MARK: - Deeplink Coordination

    /// Called by `AuthDeepLinkCoordinator` after successful email confirmation.
    ///
    /// Sets the signed-in state and fires `onSignIn` so `AuthLifecycleCoordinator`
    /// can start sync — mirroring the manual sign-in path.
    func handleEmailConfirmed(_ result: AuthSuccess) async {
        state = .signedIn(result.user)
        await onSignIn?(result.user)
    }

    // MARK: - Error Mapping

    /// Maps Supabase auth errors to user-friendly messages.
    ///
    /// Curated messages are returned for known error codes. For unmapped 4xx API errors
    /// the raw Supabase message is cleaned up and forwarded — it is a client error with
    /// a meaningful reason. 5xx errors and non-API errors fall back to a generic message
    /// to avoid exposing server internals.
    private func mapAuthError(_ error: AuthError) -> String {
        switch error {
        case .api(let message, let errorCode, _, let response):
            Self.logger.error("mapAuthError: API error code='\(errorCode.rawValue)' status=\(response.statusCode) message='\(message)'")
            switch errorCode {
            case .invalidCredentials:
                return "Invalid email or password."
            case .userNotFound:
                return "No account found with this email."
            case .sessionExpired, .sessionNotFound:
                return "Session expired. Please sign in again."
            case .emailNotConfirmed:
                return "Please verify your email first. Check your inbox."
            case .userAlreadyExists, .emailExists:
                return "An account with this email already exists."
            case .overRequestRateLimit, .overEmailSendRateLimit, .overSMSSendRateLimit:
                return "Too many attempts. Please try again later."
            default:
                if (400..<500).contains(response.statusCode) && !message.isEmpty {
                    let cleaned = cleanAPIMessage(message)
                    Self.logger.error("mapAuthError: forwarding unmapped 4xx message for code='\(errorCode.rawValue)': '\(cleaned)'")
                    return cleaned
                }
                Self.logger.error("mapAuthError: unmapped error code='\(errorCode.rawValue)' status=\(response.statusCode) — returning generic message")
                return "Authentication failed. Please try again."
            }
        default:
            Self.logger.error("mapAuthError: non-API AuthError — \(String(describing: error))")
            return "Authentication failed. Please try again."
        }
    }

    /// Capitalises the first letter of a Supabase API message and ensures it ends with a period.
    private func cleanAPIMessage(_ message: String) -> String {
        guard !message.isEmpty else { return message }
        let sentence = message.prefix(1).uppercased() + message.dropFirst()
        return sentence.hasSuffix(".") ? sentence : sentence + "."
    }

    // MARK: - Helpers

    /// Clears any error message and resets email-verification state.
    func clearError() {
        errorMessage = nil
        requiresEmailVerification = false
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
