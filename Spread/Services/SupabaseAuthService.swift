import Foundation
import Supabase

/// Production auth service that authenticates with Supabase.
///
/// Creates and manages its own Supabase client internally.
/// Use `MockAuthService` for localhost.
@MainActor
struct SupabaseAuthService: AuthService {

    // MARK: - Properties

    private let client: SupabaseClient

    // MARK: - Initialization

    /// Creates a SupabaseAuthService with the app's Supabase configuration.
    init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfiguration.url,
            supabaseKey: SupabaseConfiguration.publishableKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
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
            guard !session.isExpired else { return nil }
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

    func handle(url: URL) async throws -> AuthDeepLinkResult {
        let session = try await client.auth.session(from: url)
        var params: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let fragment = components.fragment {
                fragment.split(separator: "&").forEach {
                    let kv = $0.split(separator: "=", maxSplits: 1)
                    if kv.count == 2 { params[String(kv[0])] = String(kv[1]) }
                }
            }
            components.queryItems?.forEach { params[$0.name] = $0.value ?? "" }
        }
        if params["type"] == "recovery" {
            return .recoverySession
        }
        return .emailConfirmed(AuthSuccess(user: session.user))
    }

    func updatePassword(newPassword: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func resendVerification(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    func deleteAccount() async throws {
        _ = try await client.functions.invoke("delete-user")
    }

    var authStateChanges: AsyncStream<AuthChangeEvent> {
        AsyncStream { continuation in
            Task {
                for await (event, _) in client.auth.authStateChanges {
                    switch event {
                    case .signedOut, .userDeleted:
                        continuation.yield(.signedOut)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
        }
    }
}
