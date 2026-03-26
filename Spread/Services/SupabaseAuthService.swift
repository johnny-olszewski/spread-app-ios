import Supabase

/// Production auth service that authenticates with Supabase.
///
/// Creates and manages its own Supabase client internally.
/// Use `MockAuthService` for localhost or `DebugAuthService` to inject test errors.
@MainActor
struct SupabaseAuthService: AuthService {

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
            return AuthSuccess(user: session.user)
        } catch {
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> AuthSuccess {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        return AuthSuccess(user: session.user)
    }

    func signUp(email: String, password: String) async throws -> AuthSuccess {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        return AuthSuccess(user: response.user)
    }

    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
