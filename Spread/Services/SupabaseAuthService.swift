import Supabase

/// Production auth service that authenticates with Supabase.
///
/// Creates and manages its own Supabase client internally.
/// Use `MockAuthService` for localhost or `DebugAuthService` to inject test errors.
@MainActor
final class SupabaseAuthService: AuthService {

    // MARK: - Properties

    private let client: SupabaseClient

    // MARK: - Initialization

    /// Creates a SupabaseAuthService with the app's Supabase configuration.
    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfiguration.url,
            supabaseKey: SupabaseConfiguration.publishableKey
        )
    }

    /// Creates a SupabaseAuthService with a custom client (for testing).
    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - AuthService

    func checkSession() async -> AuthSuccess? {
        do {
            let session = try await client.auth.session
            return AuthSuccess(
                user: session.user,
                hasBackupEntitlement: readBackupEntitlement(from: session.user)
            )
        } catch {
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AuthSuccess {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        return AuthSuccess(
            user: session.user,
            hasBackupEntitlement: readBackupEntitlement(from: session.user)
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Helpers

    /// Reads the backup entitlement flag from the user's app metadata.
    private func readBackupEntitlement(from user: User) -> Bool {
        user.appMetadata["backup_entitled"]?.boolValue ?? false
    }
}
