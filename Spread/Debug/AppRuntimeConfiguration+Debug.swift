#if DEBUG
import SwiftUI

extension AppRuntimeConfiguration {
    @MainActor
    static func appClock(for launchConfiguration: AppLaunchConfiguration) -> AppClock {
        guard let startupClockContext = launchConfiguration.startupClockContext else {
            return .live()
        }

        return AppClock(
            source: .live(fixedContext: startupClockContext),
            notificationBridge: AppClockNotificationBridge.live()
        )
    }

    static func mockDataSetToLoad(
        environment: DataEnvironment,
        launchConfiguration: AppLaunchConfiguration
    ) -> MockDataSet? {
        guard environment == .localhost else {
            return nil
        }
        return launchConfiguration.mockDataSet
    }

    /// Creates a configuration with debug overrides for auth, sync, mock data, and network.
    ///
    /// Called by `AppRuntimeBootstrapFactory` in debug builds. Each closure wraps or replaces
    /// a production dependency with a debug-controllable equivalent.
    static func debug() -> AppRuntimeConfiguration {
        AppRuntimeConfiguration(
            makeAuthService: { dependencies in
                let base: AuthService = DataEnvironment.current.isLocalOnly
                    ? MockAuthService()
                    : SupabaseAuthService()
                return DebugAuthService(wrapping: base, networkMonitor: dependencies.networkMonitor)
            },
            makeSyncPolicy: {
                DebugSyncPolicy()
            },
            makeAppClock: {
                appClock(for: AppLaunchConfiguration.current)
            },
            loadMockDataSet: { journalManager in
                if let dataSet = mockDataSetToLoad(
                    environment: DataEnvironment.current,
                    launchConfiguration: AppLaunchConfiguration.current
                ) {
                    try await journalManager.loadMockDataSet(dataSet)
                }
                if let bujoMode = AppLaunchConfiguration.current.bujoMode {
                    journalManager.bujoMode = bujoMode
                }
            },
            makeDebugMenuView: { dependencies, journalManager, authManager, syncEngine, appClock in
                AnyView(
                    DebugMenuView(
                        dependencies: dependencies,
                        journalManager: journalManager,
                        authManager: authManager,
                        syncEngine: syncEngine,
                        appClock: appClock
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
