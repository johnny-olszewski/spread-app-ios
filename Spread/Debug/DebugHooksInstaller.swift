#if DEBUG
import SwiftUI

enum DebugHooksInstaller {
    static func install() {
        AppSessionHooks.makeAuthService = { container in
            let base: AuthService = DataEnvironment.current.isLocalOnly
                ? MockAuthService()
                : SupabaseAuthService()
            return DebugAuthService(wrapping: base, networkMonitor: container.networkMonitor)
        }

        AppSessionHooks.makeSyncPolicy = {
            DebugSyncPolicy()
        }

        AppSessionHooks.resolveToday = {
            AppLaunchConfiguration.current.today ?? .now
        }

        AppSessionHooks.loadMockDataSet = { journalManager in
            if let dataSet = AppLaunchConfiguration.current.mockDataSet {
                try await journalManager.loadMockDataSet(dataSet)
            }
        }

        NetworkMonitorFactory.make = {
            DebugNetworkMonitor()
        }

        DebugUIHooks.makeDebugMenuView = { container, journalManager, authManager, syncEngine, onRestartRequired in
            AnyView(
                DebugMenuView(
                    container: container,
                    journalManager: journalManager,
                    authManager: authManager,
                    syncEngine: syncEngine,
                    onRestartRequired: onRestartRequired
                )
            )
        }
    }
}
#endif
