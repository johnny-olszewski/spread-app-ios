import Auth
import struct Foundation.UUID
import Observation

/// Coordinates auth lifecycle events with sync and local data management.
///
/// Handles sign-in merge/discard logic, entitlement gating, sign-out wipe,
/// and auto-sync lifecycle. Extracted from ContentView for testability.
@Observable
@MainActor
final class AuthLifecycleCoordinator {

    /// The decision a user makes when local data exists on sign-in.
    enum MigrationDecision {
        case merge
        case discard
    }

    // MARK: - Observable State

    /// Whether a migration prompt should be shown to the user.
    var isShowingMigrationPrompt = false

    /// The user awaiting a migration decision, if any.
    private(set) var pendingMigrationUser: UUID?

    // MARK: - Dependencies

    private let authManager: AuthManager
    private let syncEngine: SyncEngine
    private let journalManager: JournalManager
    private let migrationStore: MigrationStoreProtocol

    // MARK: - Private State

    private var isHandlingSignIn = false
    private var didStartAutoSync = false

    // MARK: - Initialization

    /// Creates a coordinator with the required dependencies.
    ///
    /// - Parameters:
    ///   - authManager: The auth manager to observe entitlement state.
    ///   - syncEngine: The sync engine to start/stop and trigger syncs.
    ///   - journalManager: The journal manager for local data checks and wipe.
    ///   - migrationStore: Store for per-user migration state (defaults to UserDefaults-backed).
    init(
        authManager: AuthManager,
        syncEngine: SyncEngine,
        journalManager: JournalManager,
        migrationStore: MigrationStoreProtocol = LocalDataMigrationStore()
    ) {
        self.authManager = authManager
        self.syncEngine = syncEngine
        self.journalManager = journalManager
        self.migrationStore = migrationStore
    }

    // MARK: - Auth Callbacks

    /// Wires `onSignIn` and `onSignOut` callbacks on the auth manager.
    func wireAuthCallbacks() {
        authManager.onSignIn = { [weak self] _ in
            await self?.handleSignedIn()
        }
        authManager.onSignOut = { [weak self] in
            await self?.handleSignedOut()
        }
    }

    /// Handles the initial state when the app launches already signed in.
    func handleInitialAuthState() async {
        guard authManager.state.isSignedIn else { return }
        await handleSignedIn()
    }

    // MARK: - Sign-In

    /// Processes a sign-in event with entitlement and local data checks.
    func handleSignedIn() async {
        guard !isHandlingSignIn else { return }
        guard let userId = authManager.state.user?.id else { return }

        if pendingMigrationUser == userId || isShowingMigrationPrompt {
            return
        }

        isHandlingSignIn = true

        guard authManager.hasBackupEntitlement else {
            syncEngine.status = .backupUnavailable
            isHandlingSignIn = false
            return
        }

        let hasLocalData = await journalManager.hasLocalData()
        let hasMigrated = migrationStore.hasMigrated(userId: userId)

        if hasMigrated {
            if hasLocalData {
                await journalManager.clearLocalData()
                syncEngine.resetSyncState()
            }
            startAutoSyncIfNeeded()
            await syncEngine.syncNow()
            isHandlingSignIn = false
            return
        }

        if !hasLocalData {
            migrationStore.markMigrated(userId: userId)
            startAutoSyncIfNeeded()
            await syncEngine.syncNow()
            isHandlingSignIn = false
            return
        }

        pendingMigrationUser = userId
        isShowingMigrationPrompt = true
    }

    // MARK: - Migration Decision

    /// Applies the user's merge/discard decision for local data.
    ///
    /// - Parameter decision: Whether to merge or discard local data.
    func handleMigrationDecision(_ decision: MigrationDecision) async {
        guard let userId = pendingMigrationUser else {
            resetMigrationState()
            return
        }

        isShowingMigrationPrompt = false
        pendingMigrationUser = nil

        switch decision {
        case .merge:
            migrationStore.markMigrated(userId: userId)
            startAutoSyncIfNeeded()
            await syncEngine.syncNow()
        case .discard:
            await journalManager.clearLocalData()
            syncEngine.resetSyncState()
            migrationStore.markMigrated(userId: userId)
            startAutoSyncIfNeeded()
            await syncEngine.syncNow()
        }

        isHandlingSignIn = false
    }

    // MARK: - Sign-Out

    /// Processes a sign-out event: wipes local data and resets sync.
    func handleSignedOut() async {
        await journalManager.clearLocalData()
        syncEngine.resetSyncState()
        stopAutoSyncIfNeeded()
    }

    // MARK: - Auto-Sync Lifecycle

    private func startAutoSyncIfNeeded() {
        guard !didStartAutoSync else { return }
        syncEngine.startAutoSync()
        didStartAutoSync = true
    }

    private func stopAutoSyncIfNeeded() {
        guard didStartAutoSync else { return }
        syncEngine.stopAutoSync()
        didStartAutoSync = false
    }

    private func resetMigrationState() {
        pendingMigrationUser = nil
        isShowingMigrationPrompt = false
        isHandlingSignIn = false
    }
}
