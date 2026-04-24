import struct Auth.User
import Foundation
import SwiftData
import Testing
@testable import Spread

@MainActor
struct SyncEngineTests {

    private nonisolated static func emptyServerRowsFetcher(
        _: SyncEntityType,
        _: Int64,
        _: Int
    ) async throws -> (rows: [[String: Any]], maxRevision: Int64) {
        ([], 0)
    }

    private nonisolated static func initialServerRowsFetcher(
        _: SyncEntityType,
        _: Int64,
        _: Int
    ) async throws -> (rows: [[String: Any]], maxRevision: Int64) {
        ([], 0)
    }

    private static let wkflw17SpreadID = UUID(uuidString: "00000000-0000-0000-0000-000000171001")!
    private static let wkflw17AssignedTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000171002")!
    private static let wkflw17InboxTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000171003")!
    private static let wkflw17AssignmentID = UUID(uuidString: "00000000-0000-0000-0000-000000171004")!

    private nonisolated static func wkflw17ServerRowsFetcher(
        entityType: SyncEntityType,
        _: Int64,
        _: Int
    ) async throws -> (rows: [[String: Any]], maxRevision: Int64) {
        switch entityType {
        case .spread:
            return ([
                [
                    "id": wkflw17SpreadID.uuidString,
                    "period": "month",
                    "date": "2026-04-01",
                    "start_date": NSNull(),
                    "end_date": NSNull(),
                    "is_favorite": true,
                    "custom_name": "Launch",
                    "uses_dynamic_name": false,
                    "created_at": "2026-04-01T10:00:00.000Z",
                    "deleted_at": NSNull(),
                    "revision": 10
                ]
            ], 10)
        case .task:
            return ([
                [
                    "id": wkflw17AssignedTaskID.uuidString,
                    "title": "Assigned metadata task",
                    "body": "Ship checklist",
                    "priority": "high",
                    "due_date": "2026-04-03",
                    "date": "2026-04-01",
                    "period": "month",
                    "status": "open",
                    "created_at": "2026-04-01T10:05:00.000Z",
                    "deleted_at": NSNull(),
                    "revision": 11
                ],
                [
                    "id": wkflw17InboxTaskID.uuidString,
                    "title": "Unassigned metadata task",
                    "body": "Inbox body",
                    "priority": "medium",
                    "due_date": "2026-04-02",
                    "date": NSNull(),
                    "period": NSNull(),
                    "status": "open",
                    "created_at": "2026-04-01T10:10:00.000Z",
                    "deleted_at": NSNull(),
                    "revision": 12
                ]
            ], 12)
        case .taskAssignment:
            return ([
                [
                    "id": wkflw17AssignmentID.uuidString,
                    "task_id": wkflw17AssignedTaskID.uuidString,
                    "period": "month",
                    "date": "2026-04-01",
                    "status": "open",
                    "created_at": "2026-04-01T10:06:00.000Z",
                    "deleted_at": NSNull(),
                    "revision": 13
                ]
            ], 13)
        case .settings, .note, .collection, .noteAssignment:
            return ([], 0)
        }
    }

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

    // MARK: - WKFLW-17 Sync Validation

    /// Conditions: A clean local store pulls server rows containing approved spread personalization,
    /// task metadata, an assigned task, and a true nil-assignment task.
    /// Expected: Pull replay rebuilds the same fields and journal surfaces without phantom assignment rows.
    @Test func pullReplayRebuildsWKFLW17FieldsIntoCleanStore() async throws {
        let (engine, container, _, _) = try makeEngine(
            serverRowsFetcher: Self.wkflw17ServerRowsFetcher,
            mergeRPCCaller: { _, _ in },
            assignmentPresenceChecker: { _, _ in true }
        )

        await engine.syncNow()

        let spreadRepository = SwiftDataSpreadRepository(modelContainer: container)
        let taskRepository = SwiftDataTaskRepository(modelContainer: container)
        let manager = try await JournalManager.make(
            calendar: TestDataBuilders.testCalendar,
            today: TestDataBuilders.makeDate(year: 2026, month: 4, day: 2),
            taskRepository: taskRepository,
            spreadRepository: spreadRepository,
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            collectionRepository: InMemoryCollectionRepository()
        )

        let spread = try #require(manager.spreads.first { $0.id == Self.wkflw17SpreadID })
        let assignedTask = try #require(manager.tasks.first { $0.id == Self.wkflw17AssignedTaskID })
        let inboxTask = try #require(manager.tasks.first { $0.id == Self.wkflw17InboxTaskID })
        let monthDate = TestDataBuilders.makeDate(year: 2026, month: 4, day: 1)
        let monthModel = try #require(manager.dataModel[.month]?[monthDate])

        #expect(spread.isFavorite)
        #expect(spread.customName == "Launch")
        #expect(!spread.usesDynamicName)
        #expect(assignedTask.body == "Ship checklist")
        #expect(assignedTask.priority == .high)
        #expect(assignedTask.dueDate.map(SyncDateFormatting.formatDate) == "2026-04-03")
        #expect(assignedTask.hasPreferredAssignment)
        #expect(assignedTask.assignments.first?.id == Self.wkflw17AssignmentID)
        #expect(monthModel.tasks.contains { $0.id == assignedTask.id })
        #expect(inboxTask.body == "Inbox body")
        #expect(inboxTask.priority == .medium)
        #expect(inboxTask.hasPreferredAssignment == false)
        #expect(inboxTask.assignments.isEmpty)
        #expect(manager.inboxEntries.contains { $0.id == inboxTask.id })
    }

    /// Conditions: Local repositories enqueue spread personalization and task metadata mutations,
    /// including a task with true nil preferred assignment.
    /// Expected: Push sends merge payloads with every approved field and represents nil assignment as null date/period.
    @Test func pushSerializesWKFLW17FieldsForMergeRPCs() async throws {
        var mergeCalls: [(String, Data)] = []
        let deviceId = UUID()
        let (engine, container, _, _) = try makeEngine(
            serverRowsFetcher: Self.emptyServerRowsFetcher,
            mergeRPCCaller: { name, params in
                let data = try JSONEncoder().encode(params)
                mergeCalls.append((name, data))
            },
            assignmentPresenceChecker: { _, _ in true }
        )
        let calendar = TestDataBuilders.testCalendar
        let date = TestDataBuilders.makeDate(year: 2026, month: 4, day: 1, calendar: calendar)
        let dueDate = TestDataBuilders.makeDate(year: 2026, month: 4, day: 5, calendar: calendar)
        let spreadRepository = SwiftDataSpreadRepository(modelContainer: container, deviceId: deviceId)
        let taskRepository = SwiftDataTaskRepository(modelContainer: container, deviceId: deviceId)
        let spread = DataModel.Spread(
            period: .month,
            date: date,
            calendar: calendar,
            isFavorite: true,
            customName: "Launch",
            usesDynamicName: false
        )
        let task = DataModel.Task(
            title: "Inbox metadata task",
            body: "Body survives push",
            priority: .low,
            dueDate: dueDate,
            date: date,
            period: .month,
            hasPreferredAssignment: false,
            status: .open
        )

        try await spreadRepository.save(spread)
        try await taskRepository.save(task)
        await engine.syncNow()

        let spreadJSON = try jsonPayload(for: SyncEntityType.spread.mergeRPCName, in: mergeCalls)
        let taskJSON = try jsonPayload(for: SyncEntityType.task.mergeRPCName, in: mergeCalls)

        #expect(spreadJSON["p_is_favorite"] as? Bool == true)
        #expect(spreadJSON["p_custom_name"] as? String == "Launch")
        #expect(spreadJSON["p_uses_dynamic_name"] as? Bool == false)
        #expect(spreadJSON.keys.contains("p_is_favorite_updated_at"))
        #expect(spreadJSON.keys.contains("p_custom_name_updated_at"))
        #expect(spreadJSON.keys.contains("p_uses_dynamic_name_updated_at"))
        #expect(taskJSON["p_body"] as? String == "Body survives push")
        #expect(taskJSON["p_priority"] as? String == "low")
        #expect(taskJSON["p_due_date"] as? String == SyncDateFormatting.formatDate(dueDate))
        #expect(taskJSON["p_date"] is NSNull)
        #expect(taskJSON["p_period"] is NSNull)
        #expect(taskJSON.keys.contains("p_body_updated_at"))
        #expect(taskJSON.keys.contains("p_priority_updated_at"))
        #expect(taskJSON.keys.contains("p_due_date_updated_at"))
    }

    private func jsonPayload(
        for rpcName: String,
        in mergeCalls: [(String, Data)]
    ) throws -> [String: Any] {
        let data = try #require(mergeCalls.first { $0.0 == rpcName }?.1)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
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
            serverRowsFetcher: Self.initialServerRowsFetcher,
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
            serverRowsFetcher: Self.emptyServerRowsFetcher,
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
            serverRowsFetcher: Self.emptyServerRowsFetcher,
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

    /// Conditions: Entry was previously evaluated while the server still had assignment rows.
    /// Expected: A later zero-row state re-runs the safe repair and upgrades the marker to a backfill.
    @Test func syncReevaluatesSkippedRepairMarkersWhenServerRowsDisappear() async throws {
        var presenceChecks = 0
        var mergeCalls: [(String, Data)] = []
        let user = TestUserFactory.makeUser()
        let authManager = AuthManager(service: MockAuthService())
        authManager.setStateForTesting(.signedIn(user))

        let container = try ModelContainerFactory.makeInMemory()
        let task = DataModel.Task(
            title: "Repair me later",
            assignments: [TaskAssignment(period: .month, date: .now, status: .open)]
        )
        container.mainContext.insert(task)
        container.mainContext.insert(
            DataModel.SyncRepairMarker(
                accountId: user.id,
                entryType: SyncEntityType.task.rawValue,
                entryId: task.id,
                didBackfill: false
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
            serverRowsFetcher: Self.emptyServerRowsFetcher,
            mergeRPCCaller: { name, params in
                let data = try JSONEncoder().encode(params)
                mergeCalls.append((name, data))
            },
            assignmentPresenceChecker: { entityType, _ in
                #expect(entityType == .taskAssignment)
                presenceChecks += 1
                return false
            }
        )

        await engine.syncNow()

        #expect(presenceChecks == 1)
        #expect(mergeCalls.contains(where: { $0.0 == SyncEntityType.taskAssignment.mergeRPCName }))

        let markers = try container.mainContext.fetch(FetchDescriptor<DataModel.SyncRepairMarker>())
        #expect(markers.count == 1)
        #expect(markers.first?.didBackfill == true)
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
