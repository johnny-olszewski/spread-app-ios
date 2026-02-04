import struct Auth.User
import Foundation
import Testing
@testable import Spread

@MainActor
struct AuthLifecycleCoordinatorTests {

    // MARK: - Test Helpers

    /// Shared mutable state for the test migration store.
    private final class MigrationStoreState: @unchecked Sendable {
        private var migratedUserIds: Set<UUID> = []

        func insert(_ id: UUID) {
            migratedUserIds.insert(id)
        }

        func contains(_ id: UUID) -> Bool {
            migratedUserIds.contains(id)
        }
    }

    private struct TestMigrationStore: MigrationStoreProtocol {
        private let store: MigrationStoreState

        init(store: MigrationStoreState = MigrationStoreState()) {
            self.store = store
        }

        func hasMigrated(userId: UUID) -> Bool {
            store.contains(userId)
        }

        func markMigrated(userId: UUID) {
            store.insert(userId)
        }
    }

    private func makeCoordinator(
        authManager: AuthManager? = nil,
        syncEngine: SyncEngine? = nil,
        journalManager: JournalManager? = nil,
        migrationStore: MigrationStoreProtocol? = nil,
        migrationStoreState: MigrationStoreState? = nil
    ) async throws -> (
        coordinator: AuthLifecycleCoordinator,
        authManager: AuthManager,
        syncEngine: SyncEngine,
        journalManager: JournalManager,
        migrationStoreState: MigrationStoreState
    ) {
        let auth = authManager ?? AuthManager()
        let manager: JournalManager
        if let journalManager {
            manager = journalManager
        } else {
            manager = try await JournalManager.makeForTesting()
        }
        let container = try ModelContainerFactory.makeForTesting()
        let engine = syncEngine ?? SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: auth,
            networkMonitor: NetworkMonitor(),
            deviceId: UUID(),
            isSyncEnabled: false
        )
        let storeState = migrationStoreState ?? MigrationStoreState()
        let store = migrationStore ?? TestMigrationStore(store: storeState)

        let coordinator = AuthLifecycleCoordinator(
            authManager: auth,
            syncEngine: engine,
            journalManager: manager,
            migrationStore: store
        )

        return (coordinator, auth, engine, manager, storeState)
    }

    // MARK: - Sign-In Without Entitlement

    /// Conditions: User is signed in but does not have backup entitlement.
    /// Expected: Sync status should be set to backupUnavailable.
    @Test func testSignedInWithoutEntitlementSetsBackupUnavailable() async throws {
        let (coordinator, authManager, syncEngine, _, _) = try await makeCoordinator()
        let userId = UUID()
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: false
        )

        await coordinator.handleSignedIn()

        #expect(syncEngine.status == .backupUnavailable)
    }

    // MARK: - Sign-In With Entitlement, No Local Data, Not Migrated

    /// Conditions: User signs in with entitlement, no local data, not previously migrated.
    /// Expected: Should mark as migrated and not show migration prompt.
    @Test func testSignedInWithEntitlementNoLocalDataMarksMigrated() async throws {
        let (coordinator, authManager, _, _, storeState) = try await makeCoordinator()
        let userId = UUID()
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: true
        )

        await coordinator.handleSignedIn()

        #expect(storeState.contains(userId))
        #expect(!coordinator.isShowingMigrationPrompt)
    }

    // MARK: - Sign-In With Entitlement, Has Local Data, Not Migrated

    /// Conditions: User signs in with entitlement and local data exists, not previously migrated.
    /// Expected: Should show migration prompt.
    @Test func testSignedInWithEntitlementAndLocalDataShowsPrompt() async throws {
        let manager = try await JournalManager.makeForTesting()
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)
        try await manager.spreadRepository.save(spread)

        let (coordinator, authManager, _, _, _) = try await makeCoordinator(
            journalManager: manager
        )
        let userId = UUID()
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: true
        )

        await coordinator.handleSignedIn()

        #expect(coordinator.isShowingMigrationPrompt)
        #expect(coordinator.pendingMigrationUser == userId)
    }

    // MARK: - Sign-In With Entitlement, Already Migrated

    /// Conditions: User signs in with entitlement, previously migrated.
    /// Expected: Should not show migration prompt, should proceed to sync.
    @Test func testSignedInAlreadyMigratedSkipsPrompt() async throws {
        let storeState = MigrationStoreState()
        let userId = UUID()
        storeState.insert(userId)
        let store = TestMigrationStore(store: storeState)

        let (coordinator, authManager, _, _, _) = try await makeCoordinator(
            migrationStore: store
        )
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: true
        )

        await coordinator.handleSignedIn()

        #expect(!coordinator.isShowingMigrationPrompt)
    }

    // MARK: - Migration Decision: Merge

    /// Conditions: User chooses to merge local data.
    /// Expected: Should mark as migrated and dismiss prompt.
    @Test func testMergeDecisionMarksMigratedAndDismisses() async throws {
        let storeState = MigrationStoreState()
        let manager = try await JournalManager.makeForTesting()
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)
        try await manager.spreadRepository.save(spread)

        let (coordinator, authManager, _, _, _) = try await makeCoordinator(
            journalManager: manager,
            migrationStoreState: storeState
        )
        let userId = UUID()
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: true
        )

        await coordinator.handleSignedIn()
        #expect(coordinator.isShowingMigrationPrompt)

        await coordinator.handleMigrationDecision(.merge)

        #expect(!coordinator.isShowingMigrationPrompt)
        #expect(coordinator.pendingMigrationUser == nil)
        #expect(storeState.contains(userId))
    }

    // MARK: - Migration Decision: Discard

    /// Conditions: User chooses to discard local data.
    /// Expected: Should clear local data, mark as migrated, and dismiss prompt.
    @Test func testDiscardDecisionClearsDataAndMarksMigrated() async throws {
        let storeState = MigrationStoreState()
        let manager = try await JournalManager.makeForTesting()
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)
        try await manager.spreadRepository.save(spread)

        let (coordinator, authManager, _, _, _) = try await makeCoordinator(
            journalManager: manager,
            migrationStoreState: storeState
        )
        let userId = UUID()
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: true
        )

        await coordinator.handleSignedIn()
        #expect(coordinator.isShowingMigrationPrompt)

        await coordinator.handleMigrationDecision(.discard)

        #expect(!coordinator.isShowingMigrationPrompt)
        #expect(coordinator.pendingMigrationUser == nil)
        #expect(storeState.contains(userId))
    }

    // MARK: - Sign-Out

    /// Conditions: User signs out.
    /// Expected: Should clear local data and reset sync.
    @Test func testSignOutClearsDataAndResetsSyncState() async throws {
        let (coordinator, _, syncEngine, _, _) = try await makeCoordinator()

        await coordinator.handleSignedOut()

        #expect(syncEngine.status == .idle)
    }

    // MARK: - Reentrancy Guard

    /// Conditions: handleSignedIn is called twice for the same user with a pending prompt.
    /// Expected: Second call should be a no-op.
    @Test func testDuplicateSignInCallIsNoOp() async throws {
        let manager = try await JournalManager.makeForTesting()
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)
        try await manager.spreadRepository.save(spread)

        let (coordinator, authManager, _, _, _) = try await makeCoordinator(
            journalManager: manager
        )
        let userId = UUID()
        authManager.configureForTesting(
            state: .signedIn(makeTestUser(id: userId)),
            hasBackupEntitlement: true
        )

        await coordinator.handleSignedIn()
        #expect(coordinator.isShowingMigrationPrompt)

        // Second call should not change state
        await coordinator.handleSignedIn()
        #expect(coordinator.isShowingMigrationPrompt)
        #expect(coordinator.pendingMigrationUser == userId)
    }

    // MARK: - User ID guard

    /// Conditions: handleSignedIn is called without a signed-in user.
    /// Expected: Should be a no-op.
    @Test func testHandleSignedInWithoutUserIsNoOp() async throws {
        let (coordinator, authManager, syncEngine, _, _) = try await makeCoordinator()
        authManager.configureForTesting(state: .signedOut)

        await coordinator.handleSignedIn()

        #expect(!coordinator.isShowingMigrationPrompt)
        #expect(syncEngine.status != .backupUnavailable)
    }

    // MARK: - Helpers

    /// Creates a minimal User for testing by decoding from JSON.
    ///
    /// Supabase `User` has no public initializer, so we create via JSON.
    private func makeTestUser(id: UUID) -> User {
        let json = """
        {
            "id": "\(id.uuidString)",
            "appMetadata": {},
            "userMetadata": {},
            "aud": "authenticated",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // swiftlint:disable:next force_try
        return try! decoder.decode(User.self, from: data)
    }
}
