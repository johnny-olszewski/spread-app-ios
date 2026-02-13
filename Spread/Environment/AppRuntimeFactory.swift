import OSLog
import Supabase

/// Central factory for building an app runtime.
///
/// Handles launch-time wipe checks, dependencies creation,
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
            let tempDependencies = try AppDependencies.makeForLive(
                makeNetworkMonitor: configuration.makeNetworkMonitor
            )
            let wiper = SwiftDataStoreWiper(modelContainer: tempDependencies.modelContainer)
            try await wiper.wipeAll()
        }

        let dependencies = try AppDependencies.makeForLive(
            makeNetworkMonitor: configuration.makeNetworkMonitor
        )
        let runtime = try await makeRuntime(
            dependencies: dependencies,
            environment: currentEnvironment,
            configuration: configuration
        )

        DataEnvironment.markAsLastUsed(currentEnvironment)
        logger.info("App initialized with environment: \(currentEnvironment.rawValue, privacy: .public)")

        return runtime
    }

    /// Creates a runtime from injected dependencies (previews/tests).
    ///
    /// - Parameters:
    ///   - dependencies: The app dependencies to use.
    ///   - configuration: Optional overrides for debug/QA builds.
    @MainActor
    static func make(
        dependencies: AppDependencies,
        configuration: AppRuntimeConfiguration = AppRuntimeConfiguration()
    ) async throws -> AppRuntime {
        let currentEnvironment = DataEnvironment.current
        return try await makeRuntime(
            dependencies: dependencies,
            environment: currentEnvironment,
            configuration: configuration
        )
    }

    // MARK: - Private

    @MainActor
    private static func makeRuntime(
        dependencies: AppDependencies,
        environment: DataEnvironment,
        configuration: AppRuntimeConfiguration
    ) async throws -> AppRuntime {
        let authService = configuration.makeAuthService?(dependencies) ?? SupabaseAuthService()
        let authManager = AuthManager(service: authService)

        let today = configuration.resolveToday?() ?? .now
        let journalManager = try await dependencies.makeJournalManager(today: today)

        if let loadMockDataSet = configuration.loadMockDataSet {
            try await loadMockDataSet(journalManager)
        }

        let syncEngine = createSyncEngine(
            dependencies: dependencies,
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
            dependencies: dependencies,
            journalManager: journalManager,
            authManager: authManager,
            syncEngine: syncEngine,
            authCoordinator: coordinator,
            makeDebugMenuView: configuration.makeDebugMenuView
        )
    }

    @MainActor
    private static func createSyncEngine(
        dependencies: AppDependencies,
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
            modelContainer: dependencies.modelContainer,
            authManager: authManager,
            networkMonitor: dependencies.networkMonitor,
            deviceId: DeviceIdManager.getOrCreateDeviceId(),
            isSyncEnabled: environment.syncEnabled,
            policy: policy
        )
    }
}
