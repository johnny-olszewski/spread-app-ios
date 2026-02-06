#if DEBUG

/// Debug decorator that injects forced auth errors before delegating.
///
/// Wraps any `AuthService` and checks `DebugSyncOverrides.shared.forcedAuthError`
/// before each sign-in attempt. Use this to test error handling in the UI.
@MainActor
final class DebugAuthService: AuthService {

    // MARK: - Properties

    private let wrapped: AuthService

    // MARK: - Initialization

    /// Creates a DebugAuthService wrapping another service.
    ///
    /// - Parameter wrapping: The underlying service to delegate to.
    init(wrapping service: AuthService) {
        self.wrapped = service
    }

    // MARK: - AuthService

    func checkSession() async -> AuthSuccess? {
        await wrapped.checkSession()
    }

    func signIn(email: String, password: String) async throws -> AuthSuccess {
        if let forced = DebugSyncOverrides.shared.forcedAuthError {
            throw ForcedAuthSignInError(forced: forced)
        }
        return try await wrapped.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await wrapped.signOut()
    }
}

#endif
