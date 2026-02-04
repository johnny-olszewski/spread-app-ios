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
    @State private var pendingMigrationUser: User?
    @State private var isShowingMigrationPrompt = false
    @State private var isHandlingSignIn = false
    @State private var didStartAutoSync = false

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
        .alert("Local Data Found", isPresented: $isShowingMigrationPrompt) {
            Button("Merge into Account") {
                handleMigrationDecision(.merge)
            }
            Button("Discard Local Data", role: .destructive) {
                handleMigrationDecision(.discard)
            }
        } message: {
            Text("This device has local data from a signed-out session. Choose whether to merge it into this account or discard it.")
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
            wireAuthCallbacks(syncEngine: engine)
            if case .signedIn(let user) = authManager.state {
                await handleSignedIn(user, syncEngine: engine)
            }
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
        let manager = journalManager
        authManager.onSignIn = { user in
            await handleSignedIn(user, syncEngine: syncEngine)
        }
        authManager.onSignOut = {
            await manager?.clearLocalData()
            syncEngine.resetSyncState()
            stopAutoSyncIfNeeded(syncEngine)
        }
    }

    private enum MigrationDecision {
        case merge
        case discard
    }

    @MainActor
    private func handleSignedIn(_ user: User, syncEngine: SyncEngine) async {
        guard let journalManager else { return }
        guard !isHandlingSignIn else { return }
        if pendingMigrationUser?.id == user.id || isShowingMigrationPrompt {
            return
        }

        isHandlingSignIn = true

        let userId = user.id
        let hasLocalData = await journalManager.hasLocalData()
        let hasMigrated = LocalDataMigrationStore.hasMigrated(userId: userId)

        if hasMigrated {
            if hasLocalData {
                await journalManager.clearLocalData()
                syncEngine.resetSyncState()
            }
            startAutoSyncIfNeeded(syncEngine)
            await syncEngine.syncNow()
            isHandlingSignIn = false
            return
        }

        if !hasLocalData {
            LocalDataMigrationStore.markMigrated(userId: userId)
            startAutoSyncIfNeeded(syncEngine)
            await syncEngine.syncNow()
            isHandlingSignIn = false
            return
        }

        pendingMigrationUser = user
        isShowingMigrationPrompt = true
    }

    private func handleMigrationDecision(_ decision: MigrationDecision) {
        guard let user = pendingMigrationUser,
              let syncEngine,
              let journalManager else {
            pendingMigrationUser = nil
            isShowingMigrationPrompt = false
            isHandlingSignIn = false
            return
        }

        pendingMigrationUser = nil
        isShowingMigrationPrompt = false

        Task { @MainActor in
            switch decision {
            case .merge:
                LocalDataMigrationStore.markMigrated(userId: user.id)
                startAutoSyncIfNeeded(syncEngine)
                await syncEngine.syncNow()
            case .discard:
                await journalManager.clearLocalData()
                syncEngine.resetSyncState()
                LocalDataMigrationStore.markMigrated(userId: user.id)
                startAutoSyncIfNeeded(syncEngine)
                await syncEngine.syncNow()
            }
            isHandlingSignIn = false
        }
    }

    private func startAutoSyncIfNeeded(_ syncEngine: SyncEngine) {
        guard !didStartAutoSync else { return }
        syncEngine.startAutoSync()
        didStartAutoSync = true
    }

    private func stopAutoSyncIfNeeded(_ syncEngine: SyncEngine) {
        guard didStartAutoSync else { return }
        syncEngine.stopAutoSync()
        didStartAutoSync = false
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
