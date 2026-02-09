import OSLog
import Supabase
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async JournalManager initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
/// Auth lifecycle logic is delegated to `AuthLifecycleCoordinator`.
///
/// Supports soft restart for environment switching: calling `restartApp()` nils
/// out all managers and bumps `appSessionId` to re-trigger `.task(id:)`.
struct ContentView: View {
    @State private var journalManager: JournalManager?
    @State private var authManager: AuthManager?
    @State private var syncEngine: SyncEngine?
    @State private var coordinator: AuthLifecycleCoordinator?
    @State private var appSessionId = UUID()

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "ContentView")

    let container: DependencyContainer

    var body: some View {
        Group {
            if let journalManager, let authManager {
                RootNavigationView(
                    journalManager: journalManager,
                    authManager: authManager,
                    container: container,
                    syncEngine: syncEngine,
                    onRestartRequired: restartApp
                )
            } else {
                loadingView
            }
        }
        .task(id: appSessionId) {
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

    // MARK: - Soft Restart

    /// Tears down all managers and re-triggers app initialization.
    ///
    /// Called after an environment switch to rebuild the service graph
    /// with fresh instances bound to the new data environment.
    private func restartApp() {
        Self.logger.info("Soft restart initiated")
        journalManager = nil
        authManager = nil
        syncEngine = nil
        coordinator = nil
        appSessionId = UUID()
    }

    // MARK: - Initialization

    private func initializeApp() async {
        do {
            // Check for launch-time environment mismatch
            let currentEnvironment = DataEnvironment.current
            if DataEnvironment.requiresWipeOnLaunch(current: currentEnvironment) {
                Self.logger.warning(
                    "Environment mismatch detected (lastUsed: \(DataEnvironment.lastUsed?.rawValue ?? "nil", privacy: .public), current: \(currentEnvironment.rawValue, privacy: .public)). Wiping store."
                )
                let wiper = SwiftDataStoreWiper(modelContainer: container.modelContainer)
                try await wiper.wipeAll()
            }

            let newAuthManager = ContentView.makeAuthManager()

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

            let engine = createSyncEngine(authManager: newAuthManager)
            syncEngine = engine
            authManager = newAuthManager

            guard let journalManager else { return }

            let lifecycleCoordinator = AuthLifecycleCoordinator(
                authManager: newAuthManager,
                syncEngine: engine,
                journalManager: journalManager
            )
            coordinator = lifecycleCoordinator
            lifecycleCoordinator.wireAuthCallbacks()
            await lifecycleCoordinator.handleInitialAuthState()

            // Mark environment as last used after successful initialization
            DataEnvironment.markAsLastUsed(currentEnvironment)
            Self.logger.info("App initialized with environment: \(currentEnvironment.rawValue, privacy: .public)")
        } catch {
            // TODO: SPRD-45 - Add error handling UI for initialization failures
            fatalError("Failed to initialize JournalManager: \(error)")
        }
    }

    private func createSyncEngine(authManager: AuthManager) -> SyncEngine {
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

    private static func makeAuthManager() -> AuthManager {
        AuthManager(service: makeAuthService())
    }

    private static func makeAuthService() -> AuthService {
        #if DEBUG
        let base: AuthService = DataEnvironment.current.isLocalOnly
            ? MockAuthService()
            : SupabaseAuthService()
        return DebugAuthService(wrapping: base)
        #else
        return SupabaseAuthService()
        #endif
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
