import struct Auth.User

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

    /// Signs out the current user.
    ///
    /// - Throws: An error if sign-out fails.
    func signOut() async throws
}
