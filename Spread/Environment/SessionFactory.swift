import OSLog
import Supabase

/// Central factory for building an application session.
///
/// Handles launch-time wipe checks, dependency container creation,
/// and consistent service wiring for auth, sync, and journal state.
enum SessionFactory {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "AppSessionFactory")

    /// Creates a live session for app runtime.
    ///
    /// - Parameter configuration: Optional overrides for debug/QA builds.
    @MainActor
    static func makeLive(configuration: SessionConfiguration = SessionConfiguration()) async throws -> AppSession {
        let currentEnvironment = DataEnvironment.current

        if DataEnvironment.requiresWipeOnLaunch(current: currentEnvironment) {
            logger.warning(
                "Environment mismatch detected (lastUsed: \(DataEnvironment.lastUsed?.rawValue ?? "nil", privacy: .public), current: \(currentEnvironment.rawValue, privacy: .public)). Wiping store."
            )
            let tempContainer = try DependencyContainer.makeForLive(
                makeNetworkMonitor: configuration.makeNetworkMonitor
            )
            let wiper = SwiftDataStoreWiper(modelContainer: tempContainer.modelContainer)
            try await wiper.wipeAll()
        }

        let container = try DependencyContainer.makeForLive(
            makeNetworkMonitor: configuration.makeNetworkMonitor
        )
        let session = try await makeSession(
            container: container,
            environment: currentEnvironment,
            configuration: configuration
        )

        DataEnvironment.markAsLastUsed(currentEnvironment)
        logger.info("App initialized with environment: \(currentEnvironment.rawValue, privacy: .public)")

        return session
    }

    /// Creates a session from an injected container (previews/tests).
    ///
    /// - Parameters:
    ///   - container: The dependency container to use.
    ///   - configuration: Optional overrides for debug/QA builds.
    @MainActor
    static func make(
        container: DependencyContainer,
        configuration: SessionConfiguration = SessionConfiguration()
    ) async throws -> AppSession {
        let currentEnvironment = DataEnvironment.current
        return try await makeSession(
            container: container,
            environment: currentEnvironment,
            configuration: configuration
        )
    }

    // MARK: - Private

    @MainActor
    private static func makeSession(
        container: DependencyContainer,
        environment: DataEnvironment,
        configuration: SessionConfiguration
    ) async throws -> AppSession {
        let authService = configuration.makeAuthService?(container) ?? SupabaseAuthService()
        let authManager = AuthManager(service: authService)

        let today = configuration.resolveToday?() ?? .now
        let journalManager = try await container.makeJournalManager(today: today)

        if let loadMockDataSet = configuration.loadMockDataSet {
            try await loadMockDataSet(journalManager)
        }

        let syncEngine = createSyncEngine(
            container: container,
            authManager: authManager,
            environment: environment,
            configuration: configuration
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
            coordinator: coordinator,
            makeDebugMenuView: configuration.makeDebugMenuView
        )
    }

    @MainActor
    private static func createSyncEngine(
        container: DependencyContainer,
        authManager: AuthManager,
        environment: DataEnvironment,
        configuration: SessionConfiguration
    ) -> SyncEngine {
        let client: SupabaseClient? = environment.syncEnabled
            ? SupabaseClient(
                supabaseURL: SupabaseConfiguration.url,
                supabaseKey: SupabaseConfiguration.publishableKey
            )
            : nil

        let policy = configuration.makeSyncPolicy?() ?? DefaultSyncPolicy()

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
