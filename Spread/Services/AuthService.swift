import struct Auth.User

/// The result of a successful authentication operation.
///
/// Contains the authenticated user and their entitlement status.
struct AuthResult: Sendable {
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
    func checkSession() async -> AuthResult?

    /// Signs in with email and password.
    ///
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Returns: The auth result on success.
    /// - Throws: An error if sign-in fails.
    func signIn(email: String, password: String) async throws -> AuthResult

    /// Signs out the current user.
    ///
    /// - Throws: An error if sign-out fails.
    func signOut() async throws
}
