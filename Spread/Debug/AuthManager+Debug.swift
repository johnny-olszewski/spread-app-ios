#if DEBUG
/// Debug-only helpers for previews and testing.
extension AuthManager {
    /// Creates an AuthManager with a mock service for previews.
    static func makeForPreview() -> AuthManager {
        AuthManager(service: MockAuthService())
    }

    /// Configures auth state for testing without hitting Supabase.
    func configureForTesting(state: AuthState, hasBackupEntitlement: Bool = false) {
        setStateForTesting(state, hasBackupEntitlement: hasBackupEntitlement)
    }
}
#endif
