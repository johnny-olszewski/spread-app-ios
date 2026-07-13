import Foundation

/// Optional overrides for app runtime creation behavior.
///
/// Production builds use a default configuration (all hooks nil, standard network monitor).
/// Debug builds construct a configuration with overrides for auth selection, mock data, etc.
/// Passed as a value through the factory chain — no global mutable state.
struct AppRuntimeConfiguration {
    /// Override auth service creation (e.g., selecting `MockAuthService` for localhost).
    var makeAuthService: ((AppDependencies) -> AuthService)?

    /// Override sync policy selection.
    var makeSyncPolicy: (() -> SyncPolicy)?

    /// Override the shared app clock for debug, preview, and tests.
    var makeAppClock: (() -> AppClock)?

    /// Optional hook to load mock data after JournalManager initialization.
    var loadMockDataSet: ((JournalManager) async throws -> Void)?

    /// Override debug menu view construction for debug builds.
    var makeDebugMenuView: DebugMenuViewFactory?

    /// Override feature-flag service construction (e.g., seeding a debug override store).
    /// Nil in release — `AppDependencies` then builds a store-less service.
    var makeFeatureFlags: (@MainActor () -> any FeatureFlagProviding)?

    /// Factory for creating the network monitor.
    ///
    /// Defaults to creating a standard `NetworkMonitor`.
    var makeNetworkMonitor: @MainActor () -> any NetworkMonitoring = { NetworkMonitor() }
}
