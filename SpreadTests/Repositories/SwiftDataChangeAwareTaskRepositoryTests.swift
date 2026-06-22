import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `SwiftDataChangeAwareTaskRepository`.
///
/// Mirrors the `SwiftDataTaskRepository` cases in `SwiftDataRepositoryTests` to prove the
/// change-aware save path produces identical CRUD and sync-outbox behavior while reading
/// pre-mutation assignments/tags from a caller-supplied `EntityChange` instead of re-fetching
/// from disk.
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
        #expect(mutation?.entityType == SyncEntityType.task.rawValue)
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

        let assignment = TaskAssignment(period: .day, date: Date(timeIntervalSince1970: 1_000), status: .open)
        let task = DataModel.Task(title: "Assigned task", assignments: [assignment])

        try await repository.save(task, change: EntityChange())

        let mutations = try fetchMutations(from: container)
        #expect(mutations.map(\.entityType) == [
            SyncEntityType.task.rawValue,
            SyncEntityType.taskAssignment.rawValue
        ])

        let assignmentMutation = mutations.last
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)
    }

    /// Conditions: Save a task with an assignment, mutate the assignment's status in place,
    /// then save again passing the pre-mutation assignment via `change.previousAssignments`
    /// (as a real caller would, captured one statement before mutating).
    /// Expected: An assignment update mutation is enqueued for the same logical assignment,
    /// proving the diff is computed from the supplied descriptor rather than a disk re-fetch.
    @Test func testSaveEnqueuesAssignmentUpdateMutationFromSuppliedPreviousState() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 210) }
        )

        let assignment = TaskAssignment(period: .day, date: Date(timeIntervalSince1970: 2_000), status: .open)
        let task = DataModel.Task(title: "Assigned task", assignments: [assignment])
        try await repository.save(task, change: EntityChange())

        let previousAssignments = task.assignments
        task.assignments[0].status = .complete
        try await repository.save(task, change: EntityChange(isNew: false, previousAssignments: previousAssignments))

        let mutations = try fetchMutations(from: container)
        let assignmentUpdate = mutations.last {
            $0.entityType == SyncEntityType.taskAssignment.rawValue &&
            $0.operation == SyncOperation.update.rawValue
        }

        #expect(assignmentUpdate != nil)
        #expect(assignmentUpdate?.entityId == assignment.id)

        let record = try decodeRecord(assignmentUpdate?.recordData)
        #expect(record?["status"] as? String == EntryStatus.complete.rawValue)
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

        let assignment = TaskAssignment(period: .month, date: Date(timeIntervalSince1970: 3_000), status: .open)
        let task = DataModel.Task(title: "Delete assigned task", assignments: [assignment])
        try await repository.save(task, change: EntityChange())
        try await repository.delete(task)

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.taskAssignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)
    }

    // MARK: - Parity with SwiftDataTaskRepository

    /// Conditions: Run the same create-then-update-then-delete sequence through both
    /// `SwiftDataTaskRepository` (legacy disk re-fetch diffing) and
    /// `SwiftDataChangeAwareTaskRepository` (caller-supplied descriptor diffing), using
    /// separate in-memory containers.
    /// Expected: Both produce the same sequence of outbox entity types and operations.
    @Test func testProducesSameOutboxSequenceAsLegacyRepository() async throws {
        let legacyContainer = try ModelContainerFactory.makeInMemory()
        let changeAwareContainer = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let nowProvider = { Date(timeIntervalSince1970: 1_000) }

        let legacyRepository = SwiftDataTaskRepository(
            modelContainer: legacyContainer, deviceId: deviceId, nowProvider: nowProvider
        )
        let changeAwareRepository = SwiftDataChangeAwareTaskRepository(
            modelContainer: changeAwareContainer, deviceId: deviceId, nowProvider: nowProvider
        )

        let assignment = TaskAssignment(period: .day, date: Date(timeIntervalSince1970: 5_000), status: .open)
        let legacyTask = DataModel.Task(title: "Parity Task", assignments: [assignment])
        let changeAwareTask = DataModel.Task(
            id: legacyTask.id, title: "Parity Task", assignments: [assignment]
        )

        try await legacyRepository.save(legacyTask)
        try await changeAwareRepository.save(changeAwareTask, change: EntityChange())

        legacyTask.title = "Updated Parity Task"
        let previousAssignments = changeAwareTask.assignments
        changeAwareTask.title = "Updated Parity Task"
        try await legacyRepository.save(legacyTask)
        try await changeAwareRepository.save(
            changeAwareTask,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments)
        )

        try await legacyRepository.delete(legacyTask)
        try await changeAwareRepository.delete(changeAwareTask)

        let legacySequence = try fetchMutations(from: legacyContainer).map { ($0.entityType, $0.operation) }
        let changeAwareSequence = try fetchMutations(from: changeAwareContainer).map { ($0.entityType, $0.operation) }

        #expect(legacySequence.map(\.0) == changeAwareSequence.map(\.0))
        #expect(legacySequence.map(\.1) == changeAwareSequence.map(\.1))
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
