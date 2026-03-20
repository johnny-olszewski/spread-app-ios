import struct Auth.User
import Foundation
import SwiftData
import Testing
@testable import Spread

@MainActor
struct SyncEngineTests {

    // MARK: - Test Helpers

    /// Mock network monitor for controlling connectivity in tests.
    private final class MockNetworkMonitor: NetworkMonitoring {
        var isConnected = true
        var onConnectionChange: ((Bool) -> Void)?
    }

    /// Policy that blocks sync for testing precondition checks.
    private struct BlockingSyncPolicy: SyncPolicy {
        func shouldAllowSync() -> Bool { false }
        func forceSyncFailure() -> Bool { false }
        func forceSyncingDuration() -> TimeInterval? { nil }
    }

    /// Policy that forces sync failure for testing error recovery.
    private struct FailingSyncPolicy: SyncPolicy {
        func shouldAllowSync() -> Bool { true }
        func forceSyncFailure() -> Bool { true }
        func forceSyncingDuration() -> TimeInterval? { nil }
    }

    /// Creates a SyncEngine with in-memory storage and configurable dependencies.
    private func makeEngine(
        isSyncEnabled: Bool = true,
        isConnected: Bool = true,
        isSignedIn: Bool = true,
        hasBackupEntitlement: Bool = true,
        policy: SyncPolicy = DefaultSyncPolicy()
    ) throws -> (engine: SyncEngine, container: ModelContainer, networkMonitor: MockNetworkMonitor, authManager: AuthManager) {
        let container = try ModelContainerFactory.makeInMemory()
        let networkMonitor = MockNetworkMonitor()
        networkMonitor.isConnected = isConnected
        let authManager = AuthManager(service: MockAuthService())

        if isSignedIn {
            authManager.setStateForTesting(
                .signedIn(TestUserFactory.makeUser()),
                hasBackupEntitlement: hasBackupEntitlement
            )
        }

        let engine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: networkMonitor,
            deviceId: UUID(),
            isSyncEnabled: isSyncEnabled,
            policy: policy
        )
        return (engine, container, networkMonitor, authManager)
    }

    // MARK: - Initial State

    /// Conditions: Sync-enabled engine just created.
    /// Expected: Status is idle, outbox is empty, no last sync date.
    @Test func initialStateIsIdle() throws {
        let (engine, _, _, _) = try makeEngine()

        #expect(engine.status == .idle)
        #expect(engine.outboxCount == 0)
        #expect(engine.lastSyncDate == nil)
    }

    /// Conditions: Sync is disabled (localhost mode).
    /// Expected: Status is localOnly.
    @Test func disabledSyncShowsLocalOnly() throws {
        let (engine, _, _, _) = try makeEngine(isSyncEnabled: false)

        #expect(engine.status == .localOnly)
    }

    // MARK: - Outbox Enqueue

    /// Conditions: Enqueue a create mutation.
    /// Expected: Outbox count increments and mutation persists in SwiftData.
    @Test func enqueueMutationIncrementsOutboxCount() throws {
        let (engine, container, _, _) = try makeEngine()
        let entityId = UUID()
        let recordData = "{}".data(using: .utf8)!

        engine.enqueueMutation(
            entityType: .task,
            entityId: entityId,
            operation: .create,
            recordData: recordData
        )

        #expect(engine.outboxCount == 1)

        let descriptor = FetchDescriptor<DataModel.SyncMutation>()
        let mutations = try container.mainContext.fetch(descriptor)
        #expect(mutations.count == 1)
        #expect(mutations.first?.entityId == entityId)
        #expect(mutations.first?.entityType == SyncEntityType.task.rawValue)
        #expect(mutations.first?.operation == SyncOperation.create.rawValue)
    }

    /// Conditions: Enqueue multiple mutations of different types.
    /// Expected: Outbox count reflects all mutations.
    @Test func enqueueMultipleMutations() throws {
        let (engine, _, _, _) = try makeEngine()
        let recordData = "{}".data(using: .utf8)!

        engine.enqueueMutation(entityType: .spread, entityId: UUID(), operation: .create, recordData: recordData)
        engine.enqueueMutation(entityType: .task, entityId: UUID(), operation: .create, recordData: recordData)
        engine.enqueueMutation(entityType: .taskAssignment, entityId: UUID(), operation: .create, recordData: recordData)

        #expect(engine.outboxCount == 3)
    }

    // MARK: - Outbox Refresh

    /// Conditions: Mutations exist in the store but outboxCount is stale.
    /// Expected: refreshOutboxCount reads the true count from SwiftData.
    @Test func refreshOutboxCountMatchesStoredMutations() throws {
        let (engine, container, _, _) = try makeEngine()
        let context = container.mainContext

        // Insert directly into SwiftData (bypassing engine increment)
        context.insert(DataModel.SyncMutation(
            entityType: "tasks",
            entityId: UUID(),
            operation: "create",
            recordData: "{}".data(using: .utf8)!,
            changedFields: []
        ))
        context.insert(DataModel.SyncMutation(
            entityType: "spreads",
            entityId: UUID(),
            operation: "update",
            recordData: "{}".data(using: .utf8)!,
            changedFields: ["title"]
        ))
        try context.save()

        #expect(engine.outboxCount == 0) // stale count

        engine.refreshOutboxCount()

        #expect(engine.outboxCount == 2)
    }

    // MARK: - Sync Preconditions

    /// Conditions: Sync is disabled.
    /// Expected: syncNow is a no-op, status remains localOnly.
    @Test func syncNowNoOpWhenDisabled() async throws {
        let (engine, _, _, _) = try makeEngine(isSyncEnabled: false)

        await engine.syncNow()

        #expect(engine.status == .localOnly)
    }

    /// Conditions: Device is offline.
    /// Expected: syncNow sets status to offline.
    @Test func syncNowSetsOfflineWhenDisconnected() async throws {
        let (engine, _, _, _) = try makeEngine(isConnected: false)

        await engine.syncNow()

        #expect(engine.status == .offline)
    }

    /// Conditions: User is not signed in.
    /// Expected: syncNow is a no-op, status remains idle.
    @Test func syncNowNoOpWhenNotSignedIn() async throws {
        let (engine, _, _, _) = try makeEngine(isSignedIn: false)

        await engine.syncNow()

        #expect(engine.status == .idle)
    }

    /// Conditions: User is signed in but lacks backup entitlement.
    /// Expected: syncNow sets status to backupUnavailable.
    @Test func syncNowSetsBackupUnavailableWithoutEntitlement() async throws {
        let (engine, _, _, _) = try makeEngine(hasBackupEntitlement: false)

        await engine.syncNow()

        #expect(engine.status == .backupUnavailable)
    }

    /// Conditions: Policy blocks sync.
    /// Expected: syncNow is a no-op, status remains idle.
    @Test func syncNowNoOpWhenPolicyBlocks() async throws {
        let (engine, _, _, _) = try makeEngine(policy: BlockingSyncPolicy())

        await engine.syncNow()

        #expect(engine.status == .idle)
    }

    // MARK: - Force Sync Failure

    /// Conditions: Policy forces sync failure.
    /// Expected: Status becomes error, consecutive failures increment.
    @Test func forcedSyncFailureSetsErrorStatus() async throws {
        let (engine, _, _, _) = try makeEngine(policy: FailingSyncPolicy())

        await engine.syncNow()

        #expect(engine.status.isError)
    }

    // MARK: - Reset Sync State

    /// Conditions: Engine has mutations, cursors, and status.
    /// Expected: resetSyncState clears everything.
    @Test func resetSyncStateClearsAll() throws {
        let (engine, container, _, _) = try makeEngine()
        let recordData = "{}".data(using: .utf8)!

        // Enqueue a mutation
        engine.enqueueMutation(entityType: .task, entityId: UUID(), operation: .create, recordData: recordData)
        #expect(engine.outboxCount == 1)

        // Insert a cursor
        let context = container.mainContext
        context.insert(DataModel.SyncCursor(tableName: "tasks", lastRevision: 42, lastSyncDate: .now))
        try context.save()

        // Set status
        engine.status = .synced(.now)

        engine.resetSyncState()

        #expect(engine.status == .idle)
        #expect(engine.outboxCount == 0)
        #expect(engine.lastSyncDate == nil)

        // Verify mutations are gone
        let mutationDescriptor = FetchDescriptor<DataModel.SyncMutation>()
        let mutations = try context.fetch(mutationDescriptor)
        #expect(mutations.isEmpty)

        // Verify cursors are gone
        let cursorDescriptor = FetchDescriptor<DataModel.SyncCursor>()
        let cursors = try context.fetch(cursorDescriptor)
        #expect(cursors.isEmpty)
    }

    // MARK: - Sync Log

    /// Conditions: Various sync operations are attempted.
    /// Expected: Sync log records events.
    @Test func syncLogRecordsEvents() async throws {
        let (engine, _, _, _) = try makeEngine(isConnected: false)

        await engine.syncNow()

        let entries = engine.syncLog.entries
        #expect(!entries.isEmpty)
    }

    // MARK: - Network Monitor Integration

    /// Conditions: Network monitor reports disconnected.
    /// Expected: startAutoSync does not crash and status reflects offline when sync attempted.
    @Test func startAutoSyncWithoutEntitlementSetsBackupUnavailable() throws {
        let (engine, _, _, _) = try makeEngine(hasBackupEntitlement: false)

        engine.startAutoSync()

        #expect(engine.status == .backupUnavailable)

        engine.stopAutoSync()
    }

    /// Conditions: Sync is disabled.
    /// Expected: startAutoSync is a no-op.
    @Test func startAutoSyncNoOpWhenDisabled() throws {
        let (engine, _, _, _) = try makeEngine(isSyncEnabled: false)

        engine.startAutoSync()

        #expect(engine.status == .localOnly)

        engine.stopAutoSync()
    }
}

// MARK: - Test User Factory

/// Factory for creating test User objects.
///
/// Supabase User has no public initializer, so we decode from JSON.
private enum TestUserFactory {
    @MainActor
    static func makeUser(id: UUID = UUID(), email: String = "test@example.com") -> User {
        let json = """
        {
            "id": "\(id.uuidString)",
            "email": "\(email)",
            "appMetadata": {"backup_entitled": true},
            "userMetadata": {},
            "aud": "authenticated",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(User.self, from: data)
    }
}
