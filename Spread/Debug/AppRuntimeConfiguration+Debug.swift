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

    /// Creates a configuration with debug overrides for auth selection, app clock,
    /// mock data, and the debug menu.
    ///
    /// Called by `AppRuntimeBootstrapFactory` in debug builds.
    static func debug() -> AppRuntimeConfiguration {
        AppRuntimeConfiguration(
            makeAuthService: { _ in
                let service: AuthService = DataEnvironment.current.isLocalOnly
                    ? MockAuthService()
                    : SupabaseAuthService()
                return service
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
            makeFeatureFlags: {
                // Persistent debug-menu overrides, with per-launch argument overrides layered on top.
                let service = FeatureFlagService(overrideStore: UserDefaultsFeatureFlagOverrideStore())
                for (flag, value) in AppLaunchConfiguration.current.featureFlagOverrides {
                    service.setOverride(value, for: flag)
                }
                return service
            }
        )
    }
}
#endif
