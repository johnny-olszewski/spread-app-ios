import Foundation

/// Optional hooks for debug-only session behavior.
///
/// Set by Debug-only code to override default app session behavior
/// without polluting production files with conditional compilation.
enum AppSessionHooks {
    /// Override auth service creation (e.g., DebugAuthService wrapping Mock/Supabase).
    static var makeAuthService: ((DependencyContainer) -> AuthService)?

    /// Override sync policy selection (e.g., DebugSyncPolicy).
    static var makeSyncPolicy: (() -> SyncPolicy)?

    /// Override the "today" date used for journal initialization.
    static var resolveToday: (() -> Date)?

    /// Optional hook to load mock data after JournalManager initialization.
    static var loadMockDataSet: ((JournalManager) async throws -> Void)?
}
