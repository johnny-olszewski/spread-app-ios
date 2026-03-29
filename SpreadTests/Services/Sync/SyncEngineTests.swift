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
        policy: SyncPolicy = DefaultSyncPolicy(),
        serverRowsFetcher: SyncEngine.ServerRowsFetcher? = nil,
        mergeRPCCaller: SyncEngine.MergeRPCCaller? = nil,
        assignmentPresenceChecker: SyncEngine.AssignmentPresenceChecker? = nil
    ) throws -> (engine: SyncEngine, container: ModelContainer, networkMonitor: MockNetworkMonitor, authManager: AuthManager) {
        let container = try ModelContainerFactory.makeInMemory()
        let networkMonitor = MockNetworkMonitor()
        networkMonitor.isConnected = isConnected
        let authManager = AuthManager(service: MockAuthService())

        if isSignedIn {
            authManager.setStateForTesting(.signedIn(TestUserFactory.makeUser()))
        }

        let engine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: networkMonitor,
            deviceId: UUID(),
            isSyncEnabled: isSyncEnabled,
            policy: policy,
            serverRowsFetcher: serverRowsFetcher,
            mergeRPCCaller: mergeRPCCaller,
            assignmentPresenceChecker: assignmentPresenceChecker
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

    // MARK: - Assignment Repair

    /// Conditions: Signed-in task with local assignment history and zero server assignment rows.
    /// Expected: Sync backfills all local task assignments once and records a repair marker.
    @Test func syncBackfillsTaskAssignmentsWhenServerHasZeroRows() async throws {
        var mergeCalls: [(String, Data)] = []
        let (engine, container, _, _) = try makeEngine(
            serverRowsFetcher: { _, afterRevision, _ in
                #expect(afterRevision == 0)
                return ([], 0)
            },
            mergeRPCCaller: { name, params in
                let data = try JSONEncoder().encode(params)
                mergeCalls.append((name, data))
            },
            assignmentPresenceChecker: { entityType, _ in
                #expect(entityType == .taskAssignment)
                return false
            }
        )

        let task = DataModel.Task(
            title: "Repair me",
            assignments: [
                TaskAssignment(period: .year, date: .now, status: .migrated),
                TaskAssignment(period: .month, date: .now, status: .open)
            ]
        )
        container.mainContext.insert(task)
        try container.mainContext.save()

        await engine.syncNow()

        let taskAssignmentCalls = mergeCalls.filter { $0.0 == SyncEntityType.taskAssignment.mergeRPCName }
        #expect(taskAssignmentCalls.count == 2)

        let markers = try container.mainContext.fetch(FetchDescriptor<DataModel.SyncRepairMarker>())
        #expect(markers.count == 1)
        #expect(markers.first?.entryType == SyncEntityType.task.rawValue)
        #expect(markers.first?.entryId == task.id)
        #expect(markers.first?.didBackfill == true)
    }

    /// Conditions: Signed-in note with local assignment history and server assignment rows already present.
    /// Expected: Sync records a skip marker and does not enqueue note-assignment backfill.
    @Test func syncSkipsBackfillWhenServerAlreadyHasAssignmentRows() async throws {
        var mergeCalls: [(String, Data)] = []
        let (engine, container, _, _) = try makeEngine(
            serverRowsFetcher: { _, _, _ in ([], 0) },
            mergeRPCCaller: { name, params in
                let data = try JSONEncoder().encode(params)
                mergeCalls.append((name, data))
            },
            assignmentPresenceChecker: { entityType, _ in
                #expect(entityType == .noteAssignment)
                return true
            }
        )

        let note = DataModel.Note(
            title: "Already synced",
            assignments: [NoteAssignment(period: .day, date: .now, status: .active)]
        )
        container.mainContext.insert(note)
        try container.mainContext.save()

        await engine.syncNow()

        #expect(!mergeCalls.contains(where: { $0.0 == SyncEntityType.noteAssignment.mergeRPCName }))

        let markers = try container.mainContext.fetch(FetchDescriptor<DataModel.SyncRepairMarker>())
        #expect(markers.count == 1)
        #expect(markers.first?.entryType == SyncEntityType.note.rawValue)
        #expect(markers.first?.entryId == note.id)
        #expect(markers.first?.didBackfill == false)
    }

    /// Conditions: Entry already has a repair marker from a prior sync.
    /// Expected: Sync does not re-run backfill checks or enqueue duplicate assignment writes.
    @Test func syncBackfillRunsAtMostOncePerEntryAccount() async throws {
        var presenceChecks = 0
        var mergeCalls: [(String, Data)] = []
        let user = TestUserFactory.makeUser()
        let authManager = AuthManager(service: MockAuthService())
        authManager.setStateForTesting(.signedIn(user))

        let container = try ModelContainerFactory.makeInMemory()
        let task = DataModel.Task(
            title: "Already repaired",
            assignments: [TaskAssignment(period: .day, date: .now, status: .open)]
        )
        container.mainContext.insert(task)
        container.mainContext.insert(
            DataModel.SyncRepairMarker(
                accountId: user.id,
                entryType: SyncEntityType.task.rawValue,
                entryId: task.id,
                didBackfill: true
            )
        )
        try container.mainContext.save()

        let networkMonitor = MockNetworkMonitor()
        let engine = SyncEngine(
            client: nil,
            modelContainer: container,
            authManager: authManager,
            networkMonitor: networkMonitor,
            deviceId: UUID(),
            isSyncEnabled: true,
            policy: DefaultSyncPolicy(),
            serverRowsFetcher: { _, _, _ in ([], 0) },
            mergeRPCCaller: { name, params in
                let data = try JSONEncoder().encode(params)
                mergeCalls.append((name, data))
            },
            assignmentPresenceChecker: { _, _ in
                presenceChecks += 1
                return false
            }
        )

        await engine.syncNow()

        #expect(presenceChecks == 0)
        #expect(!mergeCalls.contains(where: { $0.0 == SyncEntityType.taskAssignment.mergeRPCName }))
    }

    // MARK: - Network Monitor Integration

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
        return try! decoder.decode(User.self, from: data)
    }
}
