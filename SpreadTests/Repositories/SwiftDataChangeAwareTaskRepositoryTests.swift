import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `SwiftDataChangeAwareTaskRepository`, the canonical task repository
/// implementation. Covers CRUD and sync-outbox behavior, including reading pre-mutation
/// assignments/tags from a caller-supplied `EntityChange` instead of re-fetching from disk.
@MainActor
struct SwiftDataChangeAwareTaskRepositoryTests {

    // MARK: - CRUD

    /// Conditions: Save a task to an empty repository with a default (new) change descriptor.
    /// Expected: Fetching tasks returns one task with the saved title.
    @Test func testSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Test Task")
        try await repository.save(task, change: EntityChange())

        let tasks = await repository.getTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Test Task")
    }

    /// Conditions: Save three tasks, each as a new entity.
    /// Expected: Fetching tasks returns three tasks.
    @Test func testSaveMultipleTasks() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(modelContainer: container)

        try await repository.save(DataModel.Task(title: "Task 1"), change: EntityChange())
        try await repository.save(DataModel.Task(title: "Task 2"), change: EntityChange())
        try await repository.save(DataModel.Task(title: "Task 3"), change: EntityChange())

        let tasks = await repository.getTasks()
        #expect(tasks.count == 3)
    }

    /// Conditions: Save a task, then delete it.
    /// Expected: Fetching tasks returns an empty list.
    @Test func testDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Task to Delete")
        try await repository.save(task, change: EntityChange())

        try await repository.delete(task)

        let tasks = await repository.getTasks()
        #expect(tasks.isEmpty)
    }

    /// Conditions: Save tasks with different created dates in non-chronological order.
    /// Expected: Fetching tasks returns them sorted by date ascending.
    @Test func testSaveReturnsTasksSortedByDateAscending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(modelContainer: container)

        let now = Date.now
        let task1 = DataModel.Task(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let task2 = DataModel.Task(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let task3 = DataModel.Task(title: "Newest", createdDate: now)

        try await repository.save(task3, change: EntityChange())
        try await repository.save(task1, change: EntityChange())
        try await repository.save(task2, change: EntityChange())

        let tasks = await repository.getTasks()
        #expect(tasks.count == 3)
        #expect(tasks[0].title == "Oldest")
        #expect(tasks[1].title == "Middle")
        #expect(tasks[2].title == "Newest")
    }

    /// Conditions: Save a task, mutate its title, then save again with `isNew: false`.
    /// Expected: Repository has one task with the updated title (no duplicate row created).
    @Test func testUpdateExistingTask() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Original Title")
        try await repository.save(task, change: EntityChange())

        task.title = "Updated Title"
        try await repository.save(task, change: EntityChange(isNew: false))

        let tasks = await repository.getTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Updated Title")
    }

    // MARK: - Sync Outbox: Parent Entity

    /// Conditions: Save a new task with `change.isNew == true`.
    /// Expected: An outbox mutation is enqueued with a create operation, with no disk re-fetch.
    @Test func testSaveEnqueuesCreateMutationFromIsNewFlag() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        let task = DataModel.Task(title: "Sync Task")
        try await repository.save(task, change: EntityChange())

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.entry.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save a task with `change.isNew == false`, simulating an update to a
    /// previously-persisted entity the caller already had in memory.
    /// Expected: An update mutation is enqueued, not a create mutation.
    @Test func testSaveEnqueuesUpdateMutationFromIsNewFlag() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 200) }
        )

        let task = DataModel.Task(title: "Existing Task")
        try await repository.save(task, change: EntityChange(isNew: false))

        let mutation = try fetchMutations(from: container).first
        #expect(mutation?.operation == SyncOperation.update.rawValue)
    }

    // MARK: - Sync Outbox: Assignments

    /// Conditions: Save a task with an initial spread assignment as a new entity.
    /// Expected: Parent task mutation is enqueued before a child task-assignment create mutation.
    @Test func testSaveEnqueuesAssignmentCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 110) }
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 1_000), status: .open)
        let task = DataModel.Task(title: "Assigned task", assignments: [assignment])

        try await repository.save(task, change: EntityChange())

        let mutations = try fetchMutations(from: container)
        #expect(mutations.map(\.entityType) == [
            SyncEntityType.entry.rawValue,
            SyncEntityType.assignment.rawValue
        ])

        let assignmentMutation = mutations.last
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)
    }

    /// Conditions: Save a task with an assignment, mutate the assignment's status in place,
    /// then save again passing the pre-mutation assignment via `change.previousAssignments`
    /// (as a real caller would, captured one statement before mutating).
    /// Expected: Per SPRD-253's outbox coalescing policy, the second save's update coalesces
    /// into the still-unsent create row for the same assignment rather than appending a second
    /// row — the row's operation stays `create` (an unsent create is never downgraded), but its
    /// record data reflects the latest status.
    @Test func testSaveEnqueuesAssignmentUpdateMutationFromSuppliedPreviousState() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 210) }
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 2_000), status: .open)
        let task = DataModel.Task(title: "Assigned task", assignments: [assignment])
        try await repository.save(task, change: EntityChange())

        let previousAssignments = task.assignments
        task.assignments[0].status = .complete
        try await repository.save(task, change: EntityChange(isNew: false, previousAssignments: previousAssignments))

        let mutations = try fetchMutations(from: container)
        let assignmentMutations = mutations.filter { $0.entityType == SyncEntityType.assignment.rawValue }
        #expect(assignmentMutations.count == 1)

        let assignmentMutation = assignmentMutations.first
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(assignmentMutation?.recordData)
        #expect(record?["status"] as? String == EntryStatus.complete.rawValue)
    }

    /// Conditions: Save a task with an assignment, clear its assignments, then save again
    /// passing the pre-mutation assignment via `change.previousAssignments`.
    /// Expected: A task-assignment tombstone is enqueued even though the parent task remains.
    @Test func testSaveEnqueuesAssignmentDeleteWhenAssignmentRemoved() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [Date(timeIntervalSince1970: 700), Date(timeIntervalSince1970: 800)]
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 4_000), status: .open)
        let task = DataModel.Task(title: "Inbox fallback", assignments: [assignment])
        try await repository.save(task, change: EntityChange())

        let previousAssignments = task.assignments
        task.assignments.removeAll()
        try await repository.save(task, change: EntityChange(isNew: false, previousAssignments: previousAssignments))

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.assignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)

        let record = try decodeRecord(assignmentDelete?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 800)))
    }

    /// Conditions: Save a task with an assignment, then delete the task.
    /// Expected: A task-assignment delete mutation is enqueued as a tombstone, derived from
    /// `task.assignments` directly (delete needs no caller-supplied change descriptor).
    @Test func testDeleteEnqueuesAssignmentDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [Date(timeIntervalSince1970: 500), Date(timeIntervalSince1970: 600)]
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = Assignment(period: .month, date: Date(timeIntervalSince1970: 3_000), status: .open)
        let task = DataModel.Task(title: "Delete assigned task", assignments: [assignment])
        try await repository.save(task, change: EntityChange())
        try await repository.delete(task)

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.assignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)
    }

    // MARK: - Batched Saves

    /// Conditions: Save three new tasks in a single `saveAll` call.
    /// Expected: All three tasks are persisted, and the outbox contains exactly one create
    /// mutation per task, in request order — the entire batch is committed as one unit, not
    /// as three independent `save` calls.
    @Test func testSaveAllPersistsAllTasksInOneCommit() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            nowProvider: { Date(timeIntervalSince1970: 300) }
        )

        let tasks = [
            DataModel.Task(title: "Batch Task 1"),
            DataModel.Task(title: "Batch Task 2"),
            DataModel.Task(title: "Batch Task 3")
        ]
        try await repository.saveAll(tasks.map { TaskSaveRequest(task: $0) })

        let savedTasks = await repository.getTasks()
        #expect(savedTasks.count == 3)

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 3)
        #expect(mutations.allSatisfy { $0.operation == SyncOperation.create.rawValue })
        #expect(mutations.map(\.entityId) == tasks.map(\.id))
    }

    /// Conditions: Save one new task and one existing task (via `isNew: false`) in the same
    /// `saveAll` call.
    /// Expected: The outbox contains a create mutation for the new task and an update mutation
    /// for the existing task, proving each request is diffed independently within the batch.
    @Test func testSaveAllDiffsEachRequestIndependently() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            nowProvider: { Date(timeIntervalSince1970: 310) }
        )

        let newTask = DataModel.Task(title: "New Task")
        let existingTask = DataModel.Task(title: "Existing Task")
        try await repository.saveAll([
            TaskSaveRequest(task: newTask),
            TaskSaveRequest(task: existingTask, change: EntityChange(isNew: false))
        ])

        let mutations = try fetchMutations(from: container)
        #expect(mutations.first { $0.entityId == newTask.id }?.operation == SyncOperation.create.rawValue)
        #expect(mutations.first { $0.entityId == existingTask.id }?.operation == SyncOperation.update.rawValue)
    }

    // MARK: - Outbox Coalescing Across a Full Mutation Sequence

    /// Conditions: Create a task with an assignment, update the task's title (assignment
    /// unchanged), then delete the task — three saves/deletes in sequence, each while the
    /// prior mutation's row is still unsent.
    /// Expected: Per SPRD-253's outbox coalescing, this produces exactly 2 final rows (task,
    /// assignment) instead of one row per mutation — the update coalesces into the still-unsent
    /// create row (stays `create`), then the final delete coalesces both down to `delete`.
    @Test func testFullMutationSequenceCoalescesToFinalRowsOnly() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let nowProvider = { Date(timeIntervalSince1970: 1_000) }

        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container, deviceId: deviceId, nowProvider: nowProvider
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 5_000), status: .open)
        let task = DataModel.Task(title: "Sequence Task", assignments: [assignment])

        try await repository.save(task, change: EntityChange())

        let previousAssignments = task.assignments
        task.title = "Updated Sequence Task"
        try await repository.save(
            task,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments)
        )

        try await repository.delete(task)

        let sequence = try fetchMutations(from: container).map { ($0.entityType, $0.operation) }

        #expect(sequence.map(\.0) == [SyncEntityType.entry.rawValue, SyncEntityType.assignment.rawValue])
        #expect(sequence.map(\.1) == [SyncOperation.delete.rawValue, SyncOperation.delete.rawValue])
    }

    // MARK: - Sync Outbox Helpers

    private func fetchMutations(from container: ModelContainer) throws -> [DataModel.SyncMutation] {
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )
        return try container.mainContext.fetch(descriptor)
    }

    private func decodeRecord(_ data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
