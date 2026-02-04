import Supabase
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async JournalManager initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
/// Auth lifecycle logic is delegated to `AuthLifecycleCoordinator`.
struct ContentView: View {
    @State private var journalManager: JournalManager?
    @State private var authManager = AuthManager(policy: ContentView.makeAuthPolicy())
    @State private var syncEngine: SyncEngine?
    @State private var coordinator: AuthLifecycleCoordinator?

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
        .alert(
            "Local Data Found",
            isPresented: Binding(
                get: { coordinator?.isShowingMigrationPrompt ?? false },
                set: { newValue in
                    if !newValue { coordinator?.isShowingMigrationPrompt = false }
                }
            )
        ) {
            Button("Merge into Account") {
                Task {
                    await coordinator?.handleMigrationDecision(.merge)
                }
            }
            Button("Discard Local Data", role: .destructive) {
                Task {
                    await coordinator?.handleMigrationDecision(.discard)
                }
            }
        } message: {
            Text(
                "This device has local data from a signed-out session. "
                    + "Choose whether to merge it into this account or discard it."
            )
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
            syncEngine = engine

            guard let journalManager else { return }

            let lifecycleCoordinator = AuthLifecycleCoordinator(
                authManager: authManager,
                syncEngine: engine,
                journalManager: journalManager
            )
            coordinator = lifecycleCoordinator
            lifecycleCoordinator.wireAuthCallbacks()
            await lifecycleCoordinator.handleInitialAuthState()
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

    private static func makeAuthPolicy() -> AuthPolicy {
        #if DEBUG
        return DebugAuthPolicy()
        #else
        return DefaultAuthPolicy()
        #endif
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
