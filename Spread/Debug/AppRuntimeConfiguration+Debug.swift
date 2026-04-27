#if DEBUG
import SwiftUI

extension AppRuntimeConfiguration {
    @MainActor
    private static func launchAppClock() -> AppClock {
        guard let today = AppLaunchConfiguration.current.today else {
            return .live()
        }

        var calendar = Calendar.autoupdatingCurrent
        let timeZone = calendar.timeZone
        let locale = calendar.locale ?? .autoupdatingCurrent
        calendar.locale = locale

        return .fixed(
            now: today,
            calendar: calendar,
            timeZone: timeZone,
            locale: locale
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
                launchAppClock()
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
            makeDebugMenuView: { dependencies, journalManager, authManager, syncEngine in
                AnyView(
                    DebugMenuView(
                        dependencies: dependencies,
                        journalManager: journalManager,
                        authManager: authManager,
                        syncEngine: syncEngine
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
