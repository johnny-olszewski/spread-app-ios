#if DEBUG

/// Debug decorator that injects forced auth errors and network blocking before delegating.
///
/// Wraps any `AuthService` and checks `forcedAuthError` and the network monitor's
/// connectivity before each sign-in attempt. Use this to test error handling in the UI.
@MainActor
final class DebugAuthService: AuthService {

    // MARK: - Properties

    private let wrapped: AuthService
    private let networkMonitor: any NetworkMonitoring

    /// When set, forces sign-in to fail with this error before hitting Supabase.
    var forcedAuthError: ForcedAuthError?

    // MARK: - Initialization

    /// Creates a DebugAuthService wrapping another service.
    ///
    /// - Parameters:
    ///   - wrapping: The underlying service to delegate to.
    ///   - networkMonitor: The network monitor to check connectivity before sign-in.
    init(wrapping service: AuthService, networkMonitor: any NetworkMonitoring) {
        self.wrapped = service
        self.networkMonitor = networkMonitor
    }

    // MARK: - AuthService

    func checkSession() async -> AuthSuccess? {
        await wrapped.checkSession()
    }

    func signIn(email: String, password: String) async throws -> AuthSuccess {
        if !networkMonitor.isConnected {
            throw ForcedAuthSignInError(forced: .networkTimeout)
        }
        if let forced = forcedAuthError {
            throw ForcedAuthSignInError(forced: forced)
        }
        return try await wrapped.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await wrapped.signOut()
    }
}

#endif
