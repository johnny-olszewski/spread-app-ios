import Supabase
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async JournalManager initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
struct ContentView: View {
    @State private var journalManager: JournalManager?
    @State private var authManager = AuthManager()
    @State private var syncEngine: SyncEngine?

    let container: DependencyContainer

    var body: some View {
        Group {
            if let journalManager {
                RootNavigationView(
                    journalManager: journalManager,
                    authManager: authManager,
                    container: container,
                    syncEngine: syncEngine
                )
            } else {
                loadingView
            }
        }
        .task {
            await initializeApp()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Initialization

    private func initializeApp() async {
        do {
            #if DEBUG
            let launchConfiguration = AppLaunchConfiguration.current
            let resolvedToday = launchConfiguration.today ?? .now

            var manager = try await container.makeJournalManager(today: resolvedToday)
            if let dataSet = launchConfiguration.mockDataSet {
                try await manager.loadMockDataSet(dataSet)
            }
            journalManager = manager
            #else
            journalManager = try await container.makeJournalManager()
            #endif

            let engine = createSyncEngine()
            wireAuthCallbacks(syncEngine: engine)
            syncEngine = engine
            engine.startAutoSync()
        } catch {
            // TODO: SPRD-45 - Add error handling UI for initialization failures
            fatalError("Failed to initialize JournalManager: \(error)")
        }
    }

    private func createSyncEngine() -> SyncEngine {
        let dataEnv = DataEnvironment.current
        let client: SupabaseClient? = dataEnv.syncEnabled
            ? SupabaseClient(
                supabaseURL: SupabaseConfiguration.url,
                supabaseKey: SupabaseConfiguration.publishableKey
            )
            : nil

        return SyncEngine(
            client: client,
            modelContainer: container.modelContainer,
            authManager: authManager,
            networkMonitor: container.networkMonitor,
            deviceId: DeviceIdManager.getOrCreateDeviceId(),
            isSyncEnabled: dataEnv.syncEnabled,
            policy: makeSyncPolicy()
        )
    }

    private func makeSyncPolicy() -> SyncPolicy {
        #if DEBUG
        return DebugSyncPolicy()
        #else
        return DefaultSyncPolicy()
        #endif
    }

    private func wireAuthCallbacks(syncEngine: SyncEngine) {
        authManager.onSignIn = { _ in
            await syncEngine.syncNow()
        }
        authManager.onSignOut = {
            syncEngine.resetSyncState()
        }
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
