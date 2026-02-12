#if DEBUG
import SwiftUI

extension SessionConfiguration {
    /// Creates a configuration with debug overrides for auth, sync, mock data, and network.
    ///
    /// Called by `AppSessionFactory` in debug builds. Each closure wraps or replaces
    /// a production dependency with a debug-controllable equivalent.
    static func debug() -> SessionConfiguration {
        SessionConfiguration(
            makeAuthService: { container in
                let base: AuthService = DataEnvironment.current.isLocalOnly
                    ? MockAuthService()
                    : SupabaseAuthService()
                return DebugAuthService(wrapping: base, networkMonitor: container.networkMonitor)
            },
            makeSyncPolicy: {
                DebugSyncPolicy()
            },
            resolveToday: {
                AppLaunchConfiguration.current.today ?? .now
            },
            loadMockDataSet: { journalManager in
                if let dataSet = AppLaunchConfiguration.current.mockDataSet {
                    try await journalManager.loadMockDataSet(dataSet)
                }
            },
            makeDebugMenuView: { container, journalManager, authManager, syncEngine, onRestartRequired in
                AnyView(
                    DebugMenuView(
                        container: container,
                        journalManager: journalManager,
                        authManager: authManager,
                        syncEngine: syncEngine,
                        onRestartRequired: onRestartRequired
                    )
                )
            },
            makeNetworkMonitor: {
                DebugNetworkMonitor()
            }
        )
    }
}
#endif
