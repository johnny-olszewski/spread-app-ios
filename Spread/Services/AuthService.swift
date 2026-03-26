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

    /// Signs out the current user.
    ///
    /// - Throws: An error if sign-out fails.
    func signOut() async throws
}
