import AuthenticationServices
import struct Auth.User

/// Error during Apple Sign-In flow.
enum AppleSignInError: Error, LocalizedError {
    /// The identity token was missing from the Apple credential.
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple sign-in failed: missing identity token."
        }
    }
}

/// Successful authentication outcome.
///
/// Contains the authenticated user and their entitlement status.
struct AuthSuccess: Sendable {
    /// The authenticated user.
    let user: User

    /// Whether the user has backup entitlement.
    let hasBackupEntitlement: Bool
}

/// Service that performs authentication operations.
///
/// Implementations include:
/// - `SupabaseAuthService`: Real Supabase authentication for production.
/// - `MockAuthService`: Instant success for localhost/testing.
/// - `DebugAuthService`: Decorator that injects forced errors for testing.
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

    /// Signs in with Apple using a native credential.
    ///
    /// - Parameter credential: The Apple ID credential from `ASAuthorizationController`.
    /// - Returns: The auth result on success.
    /// - Throws: An error if sign-in fails.
    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async throws -> AuthSuccess

    /// Signs in with Google using Supabase OAuth.
    ///
    /// Opens a web-based OAuth flow via `ASWebAuthenticationSession`.
    /// - Returns: The auth result on success.
    /// - Throws: An error if sign-in fails.
    func signInWithGoogle() async throws -> AuthSuccess

    /// Signs out the current user.
    ///
    /// - Throws: An error if sign-out fails.
    func signOut() async throws
}
