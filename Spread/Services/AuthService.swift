import Foundation
import struct Auth.User

/// Successful authentication outcome.
struct AuthSuccess: Sendable {
    /// The authenticated user.
    let user: User
}

/// Service that performs authentication operations.
///
/// Implementations include:
/// - `SupabaseAuthService`: Real Supabase authentication for production.
/// - `MockAuthService`: Instant success for localhost/testing.
@MainActor
protocol AuthService: Sendable {

    /// Checks for an existing session on startup.
    ///
    /// - Returns: The auth result if a valid session exists, nil otherwise.
    func checkSession() async -> AuthSuccess?

    /// Signs in with email and password.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: The auth result on success.
    /// - Throws: An error if sign-in fails.
    func signIn(email: String, password: String) async throws -> AuthSuccess

    /// Creates a new account with email and password.
    ///
    /// - Parameters:
    ///   - email: The new user's email address.
    ///   - password: The new user's password.
    /// - Returns: The auth result on success.
    /// - Throws: An error if sign-up fails.
    func signUp(email: String, password: String) async throws -> AuthSuccess

    /// Sends a password reset email.
    ///
    /// - Parameter email: The email address to send the reset link to.
    /// - Throws: An error if the request fails.
    func resetPassword(email: String) async throws

    /// Signs out the current user.
    ///
    /// - Throws: An error if sign-out fails.
    func signOut() async throws

    /// Exchanges a Supabase auth callback URL for a session.
    ///
    /// - Parameter url: The deeplink URL delivered via `onOpenURL`.
    /// - Returns: The deeplink result indicating email confirmation or password recovery.
    /// - Throws: An error if the token exchange fails.
    func handle(url: URL) async throws -> AuthDeepLinkResult

    /// Updates the current signed-in user's password.
    ///
    /// - Parameter newPassword: The replacement password.
    /// - Throws: An error if the update fails.
    func updatePassword(newPassword: String) async throws

    /// Resends the verification email to the given address.
    ///
    /// - Parameter email: The email address to resend verification to.
    /// - Throws: An error if the request fails.
    func resendVerification(email: String) async throws

    /// Permanently deletes the current user's account and all associated data.
    ///
    /// Calls the `delete-user` Supabase Edge Function which uses service-role
    /// permissions to hard-delete the user via `auth.admin.deleteUser`.
    /// - Throws: An error if the deletion fails.
    func deleteAccount() async throws

    /// Async stream of externally-triggered auth state changes.
    ///
    /// Emits `.signedOut` when the session is terminated outside the app
    /// (e.g., token expiry, account deletion). Never emits for manual sign-out.
    var authStateChanges: AsyncStream<AuthChangeEvent> { get }
}
