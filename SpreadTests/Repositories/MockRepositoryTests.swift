import struct Foundation.Date
import struct Foundation.UUID
import Testing
@testable import Spread

/// Tests for mock and in-memory repository implementations.
@MainActor
struct MockRepositoryTests {

    // MARK: - InMemoryTaskRepository Tests

    @Test func testInMemoryTaskRepositorySaveAddsTask() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Test Task")

        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Test Task")
    }

    @Test func testInMemoryTaskRepositorySaveIsIdempotent() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Test Task")

        try await repository.save(task)
        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == 1)
    }

    @Test func testInMemoryTaskRepositorySaveUpdatesExisting() async throws {
        let repository = InMemoryTaskRepository()
        let taskId = UUID()
        let task = DataModel.Task(id: taskId, title: "Original")

        try await repository.save(task)
        task.title = "Updated"
        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Updated")
    }

    @Test func testInMemoryTaskRepositoryDeleteRemovesTask() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Test Task")

        try await repository.save(task)
        try await repository.delete(task)
        let tasks = await repository.getTasks()

        #expect(tasks.isEmpty)
    }

    @Test func testInMemoryTaskRepositoryDeleteNonExistentIsNoOp() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Non-existent")

        try await repository.delete(task)
        let tasks = await repository.getTasks()

        #expect(tasks.isEmpty)
    }

    @Test func testInMemoryTaskRepositoryInitializesWithTasks() async {
        let existingTasks = [
            DataModel.Task(title: "Task 1"),
            DataModel.Task(title: "Task 2")
        ]
        let repository = InMemoryTaskRepository(tasks: existingTasks)

        let tasks = await repository.getTasks()

        #expect(tasks.count == 2)
    }

    @Test func testInMemoryTaskRepositorySortsByDateAscending() async throws {
        let repository = InMemoryTaskRepository()
        let now = Date.now
        let task1 = DataModel.Task(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let task2 = DataModel.Task(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let task3 = DataModel.Task(title: "Newest", createdDate: now)

        try await repository.save(task3)
        try await repository.save(task1)
        try await repository.save(task2)
        let tasks = await repository.getTasks()

        #expect(tasks[0].title == "Oldest")
        #expect(tasks[1].title == "Middle")
        #expect(tasks[2].title == "Newest")
    }

    // MARK: - InMemorySpreadRepository Tests

    @Test func testInMemorySpreadRepositorySaveAddsSpread() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread()

        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == 1)
    }

    @Test func testInMemorySpreadRepositorySaveIsIdempotent() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread()

        try await repository.save(spread)
        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == 1)
    }

    @Test func testInMemorySpreadRepositoryDeleteRemovesSpread() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread()

        try await repository.save(spread)
        try await repository.delete(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.isEmpty)
    }

    @Test func testInMemorySpreadRepositoryDeleteNonExistentIsNoOp() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread()

        try await repository.delete(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.isEmpty)
    }

    @Test func testInMemorySpreadRepositoryInitializesWithSpreads() async {
        let existingSpreads = [
            DataModel.Spread(),
            DataModel.Spread()
        ]
        let repository = InMemorySpreadRepository(spreads: existingSpreads)

        let spreads = await repository.getSpreads()

        #expect(spreads.count == 2)
    }

    @Test func testInMemorySpreadRepositorySortsByDateDescending() async throws {
        let repository = InMemorySpreadRepository()
        let now = Date.now
        let spread1 = DataModel.Spread(createdDate: now.addingTimeInterval(-200))
        let spread2 = DataModel.Spread(createdDate: now.addingTimeInterval(-100))
        let spread3 = DataModel.Spread(createdDate: now)

        try await repository.save(spread1)
        try await repository.save(spread3)
        try await repository.save(spread2)
        let spreads = await repository.getSpreads()

        #expect(spreads[0].createdDate == now)
        #expect(spreads[1].createdDate == now.addingTimeInterval(-100))
        #expect(spreads[2].createdDate == now.addingTimeInterval(-200))
    }

    // MARK: - MockTaskRepository Tests

    @Test func testMockTaskRepositoryProvidesSampleTasks() async {
        let repository = MockTaskRepository()
        let tasks = await repository.getTasks()

        #expect(!tasks.isEmpty)
    }

    @Test func testMockTaskRepositorySupportsSave() async throws {
        let repository = MockTaskRepository()
        let initialCount = await repository.getTasks().count
        let task = DataModel.Task(title: "New Task")

        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == initialCount + 1)
    }

    @Test func testMockTaskRepositorySupportsDelete() async throws {
        let repository = MockTaskRepository()
        let tasks = await repository.getTasks()
        guard let taskToDelete = tasks.first else {
            Issue.record("No tasks to delete")
            return
        }

        try await repository.delete(taskToDelete)
        let remainingTasks = await repository.getTasks()

        #expect(!remainingTasks.contains { $0.id == taskToDelete.id })
    }

    // MARK: - MockSpreadRepository Tests

    @Test func testMockSpreadRepositoryProvidesSampleSpreads() async {
        let repository = MockSpreadRepository()
        let spreads = await repository.getSpreads()

        #expect(!spreads.isEmpty)
    }

    @Test func testMockSpreadRepositorySupportsSave() async throws {
        let repository = MockSpreadRepository()
        let initialCount = await repository.getSpreads().count
        let spread = DataModel.Spread()

        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == initialCount + 1)
    }

    @Test func testMockSpreadRepositorySupportsDelete() async throws {
        let repository = MockSpreadRepository()
        let spreads = await repository.getSpreads()
        guard let spreadToDelete = spreads.first else {
            Issue.record("No spreads to delete")
            return
        }

        try await repository.delete(spreadToDelete)
        let remainingSpreads = await repository.getSpreads()

        #expect(!remainingSpreads.contains { $0.id == spreadToDelete.id })
    }

    // MARK: - TestData Tests

    @Test func testTestDataGeneratesSampleTasks() {
        let tasks = TestData.sampleTasks()

        #expect(!tasks.isEmpty)
        #expect(tasks.allSatisfy { !$0.title.isEmpty })
    }

    @Test func testTestDataGeneratesSampleSpreads() {
        let spreads = TestData.sampleSpreads()

        #expect(!spreads.isEmpty)
    }

    @Test func testTestDataTasksHaveUniqueIds() {
        let tasks = TestData.sampleTasks()
        let ids = Set(tasks.map(\.id))

        #expect(ids.count == tasks.count)
    }

    @Test func testTestDataSpreadsHaveUniqueIds() {
        let spreads = TestData.sampleSpreads()
        let ids = Set(spreads.map(\.id))

        #expect(ids.count == spreads.count)
    }
}
