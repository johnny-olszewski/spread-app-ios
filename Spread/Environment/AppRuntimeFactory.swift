import OSLog
import Supabase

/// Central factory for building an app runtime.
///
/// Handles launch-time wipe checks, dependency container creation,
/// and consistent service wiring for auth, sync, and journal state.
enum AppRuntimeFactory {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "AppRuntimeFactory")

    /// Creates a live runtime for app launch.
    ///
    /// - Parameter configuration: Optional overrides for debug/QA builds.
    @MainActor
    static func makeLive(configuration: AppRuntimeConfiguration = AppRuntimeConfiguration()) async throws -> AppRuntime {
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
        let runtime = try await makeRuntime(
            container: container,
            environment: currentEnvironment,
            configuration: configuration
        )

        DataEnvironment.markAsLastUsed(currentEnvironment)
        logger.info("App initialized with environment: \(currentEnvironment.rawValue, privacy: .public)")

        return runtime
    }

    /// Creates a runtime from an injected container (previews/tests).
    ///
    /// - Parameters:
    ///   - container: The dependency container to use.
    ///   - configuration: Optional overrides for debug/QA builds.
    @MainActor
    static func make(
        container: DependencyContainer,
        configuration: AppRuntimeConfiguration = AppRuntimeConfiguration()
    ) async throws -> AppRuntime {
        let currentEnvironment = DataEnvironment.current
        return try await makeRuntime(
            container: container,
            environment: currentEnvironment,
            configuration: configuration
        )
    }

    // MARK: - Private

    @MainActor
    private static func makeRuntime(
        container: DependencyContainer,
        environment: DataEnvironment,
        configuration: AppRuntimeConfiguration
    ) async throws -> AppRuntime {
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

        return AppRuntime(
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
        configuration: AppRuntimeConfiguration
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
