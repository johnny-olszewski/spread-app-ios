import Foundation

/// Optional overrides for app runtime creation behavior.
///
/// Production builds use a default configuration (all hooks nil, standard network monitor).
/// Debug builds construct a configuration with overrides for auth, sync, mock data, etc.
/// Passed as a value through the factory chain — no global mutable state.
struct AppRuntimeConfiguration {
    /// Override auth service creation (e.g., DebugAuthService wrapping Mock/Supabase).
    var makeAuthService: ((DependencyContainer) -> AuthService)?

    /// Override sync policy selection (e.g., DebugSyncPolicy).
    var makeSyncPolicy: (() -> SyncPolicy)?

    /// Override the "today" date used for journal initialization.
    var resolveToday: (() -> Date)?

    /// Optional hook to load mock data after JournalManager initialization.
    var loadMockDataSet: ((JournalManager) async throws -> Void)?

    /// Override debug menu view construction for debug/QA builds.
    var makeDebugMenuView: DebugMenuViewFactory?

    /// Factory for creating the network monitor.
    ///
    /// Defaults to creating a standard `NetworkMonitor`.
    var makeNetworkMonitor: @MainActor () -> any NetworkMonitoring = { NetworkMonitor() }
}
