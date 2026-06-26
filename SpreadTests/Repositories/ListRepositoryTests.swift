import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `SwiftDataListRepository` CRUD operations and inverse relationships.
@MainActor
struct ListRepositoryTests {

    // MARK: - CRUD

    /// Conditions: Save a list to an empty in-memory repository.
    /// Expected: getLists returns the saved list with the correct name.
    @Test func testSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataListRepository(modelContainer: container)

        let list = DataModel.List(name: "Work")
        try await repo.save(list)

        let lists = await repo.getLists()
        #expect(lists.count == 1)
        #expect(lists.first?.name == "Work")
    }

    /// Conditions: Save three lists to the repository.
    /// Expected: getLists returns all three, sorted alphabetically by name.
    @Test func testGetListsReturnsSortedByName() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataListRepository(modelContainer: container)

        try await repo.save(DataModel.List(name: "Work"))
        try await repo.save(DataModel.List(name: "Home"))
        try await repo.save(DataModel.List(name: "Personal"))

        let lists = await repo.getLists()
        #expect(lists.count == 3)
        #expect(lists.map(\.name) == ["Home", "Personal", "Work"])
    }

    /// Conditions: Save a list then delete it.
    /// Expected: getLists returns an empty array.
    @Test func testDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataListRepository(modelContainer: container)

        let list = DataModel.List(name: "Temporary")
        try await repo.save(list)
        #expect(await repo.getLists().count == 1)

        try await repo.delete(list)
        #expect(await repo.getLists().isEmpty)
    }

    /// Conditions: Save a list, update its name, save again.
    /// Expected: Only one list exists with the updated name.
    @Test func testUpdateExistingList() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataListRepository(modelContainer: container)

        let list = DataModel.List(name: "Original")
        try await repo.save(list)

        list.name = "Updated"
        try await repo.save(list)

        let lists = await repo.getLists()
        #expect(lists.count == 1)
        #expect(lists.first?.name == "Updated")
    }

    // MARK: - Relationships

    /// Conditions: A task is assigned to a list, then the task is saved.
    /// Expected: The task's list property is non-nil and points to the correct list.
    @Test func testAddingTaskToListSetsInverseRelationship() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let listRepo = SwiftDataListRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let list = DataModel.List(name: "Work")
        try await listRepo.save(list)

        let task = DataModel.Task(title: "Write report", list: list)
        try await taskRepo.save(task, change: EntityChange())

        let tasks = await taskRepo.getTasks()
        #expect(tasks.first?.list?.name == "Work")
    }

    /// Conditions: Deleting a SwiftData.List with nullify delete rule while a task references it.
    /// Expected: After deletion, the task's list property becomes nil.
    @Test func testDeletingListNilsOutTaskList() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let listRepo = SwiftDataListRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let list = DataModel.List(name: "Work")
        try await listRepo.save(list)

        let task = DataModel.Task(title: "Meeting notes", list: list)
        try await taskRepo.save(task, change: EntityChange())

        try await listRepo.delete(list)

        let tasks = await taskRepo.getTasks()
        #expect(tasks.first?.list == nil)
    }

    /// Conditions: A list with two tasks assigned; both tasks are non-deleted.
    /// Expected: The non-deleted task count equals 2 — matching what the delete confirmation dialog shows.
    @Test func testDeleteConfirmationCountMatchesAffectedTasks() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let listRepo = SwiftDataListRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let list = DataModel.List(name: "Work")
        try await listRepo.save(list)

        let task1 = DataModel.Task(title: "Task One", list: list)
        let task2 = DataModel.Task(title: "Task Two", list: list)
        try await taskRepo.save(task1, change: EntityChange())
        try await taskRepo.save(task2, change: EntityChange())

        let count = list.tasks.filter { $0.deletedAt == nil }.count
        #expect(count == 2)
    }

    // MARK: - Sync Outbox

    /// Conditions: Save a new list.
    /// Expected: A SyncMutation with entityType "lists" and operation "create" is enqueued.
    @Test func testSaveEnqueuesCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataListRepository(modelContainer: container)

        let list = DataModel.List(name: "Personal")
        try await repo.save(list)

        let context = container.mainContext
        let mutations = try context.fetch(FetchDescriptor<DataModel.SyncMutation>())
        let listMutation = mutations.first { $0.entityType == "lists" }
        #expect(listMutation != nil)
        #expect(listMutation?.operation == "create")
    }

    /// Conditions: Delete a list.
    /// Expected: A SyncMutation with entityType "lists" and operation "delete" is enqueued.
    @Test func testDeleteEnqueuesDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataListRepository(modelContainer: container)

        let list = DataModel.List(name: "Temp")
        try await repo.save(list)
        try await repo.delete(list)

        let context = container.mainContext
        let mutations = try context.fetch(FetchDescriptor<DataModel.SyncMutation>())
        let deleteMutation = mutations.first { $0.entityType == "lists" && $0.operation == "delete" }
        #expect(deleteMutation != nil)
    }
}
