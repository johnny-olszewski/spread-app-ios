import OSLog
import Supabase

/// Aggregates app-level services created for a running session.
struct AppSession {
    let container: DependencyContainer
    let journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine
    let coordinator: AuthLifecycleCoordinator
}

/// Central factory for building an application session.
///
/// Handles launch-time wipe checks, dependency container creation,
/// and consistent service wiring for auth, sync, and journal state.
enum ProdAppSessionFactory {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "AppSessionFactory")

    /// Creates a live session for app runtime.
    @MainActor
    static func makeLive() async throws -> AppSession {
        let currentEnvironment = DataEnvironment.current

        if DataEnvironment.requiresWipeOnLaunch(current: currentEnvironment) {
            logger.warning(
                "Environment mismatch detected (lastUsed: \(DataEnvironment.lastUsed?.rawValue ?? "nil", privacy: .public), current: \(currentEnvironment.rawValue, privacy: .public)). Wiping store."
            )
            let tempContainer = try DependencyContainer.makeForLive()
            let wiper = SwiftDataStoreWiper(modelContainer: tempContainer.modelContainer)
            try await wiper.wipeAll()
        }

        let container = try DependencyContainer.makeForLive()
        let session = try await makeSession(container: container, environment: currentEnvironment)

        DataEnvironment.markAsLastUsed(currentEnvironment)
        logger.info("App initialized with environment: \(currentEnvironment.rawValue, privacy: .public)")

        return session
    }

    /// Creates a session from an injected container (previews/tests).
    @MainActor
    static func make(container: DependencyContainer) async throws -> AppSession {
        let currentEnvironment = DataEnvironment.current
        return try await makeSession(container: container, environment: currentEnvironment)
    }

    // MARK: - Private

    @MainActor
    private static func makeSession(
        container: DependencyContainer,
        environment: DataEnvironment
    ) async throws -> AppSession {
        let authService = AppSessionHooks.makeAuthService?(container) ?? SupabaseAuthService()
        let authManager = AuthManager(service: authService)

        let today = AppSessionHooks.resolveToday?() ?? .now
        let journalManager = try await container.makeJournalManager(today: today)

        if let loadMockDataSet = AppSessionHooks.loadMockDataSet {
            try await loadMockDataSet(journalManager)
        }

        let syncEngine = createSyncEngine(
            container: container,
            authManager: authManager,
            environment: environment
        )

        let coordinator = AuthLifecycleCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            journalManager: journalManager
        )
        coordinator.wireAuthCallbacks()
        await coordinator.handleInitialAuthState()

        return AppSession(
            container: container,
            journalManager: journalManager,
            authManager: authManager,
            syncEngine: syncEngine,
            coordinator: coordinator
        )
    }

    @MainActor
    private static func createSyncEngine(
        container: DependencyContainer,
        authManager: AuthManager,
        environment: DataEnvironment
    ) -> SyncEngine {
        let client: SupabaseClient? = environment.syncEnabled
            ? SupabaseClient(
                supabaseURL: SupabaseConfiguration.url,
                supabaseKey: SupabaseConfiguration.publishableKey
            )
            : nil

        let policy = AppSessionHooks.makeSyncPolicy?() ?? DefaultSyncPolicy()

        return SyncEngine(
            client: client,
            modelContainer: container.modelContainer,
            authManager: authManager,
            networkMonitor: container.networkMonitor,
            deviceId: DeviceIdManager.getOrCreateDeviceId(),
            isSyncEnabled: environment.syncEnabled,
            policy: policy
        )
    }
}
