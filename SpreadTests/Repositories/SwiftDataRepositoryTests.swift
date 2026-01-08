import struct Foundation.Date
import SwiftData
import Testing
@testable import Spread

/// Integration tests for SwiftData repository implementations.
///
/// Tests CRUD operations using in-memory containers for isolation.
@MainActor
struct SwiftDataRepositoryTests {

    // MARK: - TaskRepository Tests

    @Test func testTaskRepositorySaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Test Task")
        try await repository.save(task)

        let tasks = await repository.getTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Test Task")
    }

    @Test func testTaskRepositorySaveMultipleTasks() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task1 = DataModel.Task(title: "Task 1")
        let task2 = DataModel.Task(title: "Task 2")
        let task3 = DataModel.Task(title: "Task 3")

        try await repository.save(task1)
        try await repository.save(task2)
        try await repository.save(task3)

        let tasks = await repository.getTasks()
        #expect(tasks.count == 3)
    }

    @Test func testTaskRepositoryDelete() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Task to Delete")
        try await repository.save(task)

        var tasks = await repository.getTasks()
        #expect(tasks.count == 1)

        try await repository.delete(task)

        tasks = await repository.getTasks()
        #expect(tasks.count == 0)
    }

    @Test func testTaskRepositoryUpdateExistingTask() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Original Title")
        try await repository.save(task)

        task.title = "Updated Title"
        try await repository.save(task)

        let tasks = await repository.getTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Updated Title")
    }

    @Test func testTaskRepositoryReturnsTasksSortedByDateAscending() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let now = Date.now
        let task1 = DataModel.Task(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let task2 = DataModel.Task(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let task3 = DataModel.Task(title: "Newest", createdDate: now)

        // Save in non-chronological order
        try await repository.save(task3)
        try await repository.save(task1)
        try await repository.save(task2)

        let tasks = await repository.getTasks()
        #expect(tasks.count == 3)
        #expect(tasks[0].title == "Oldest")
        #expect(tasks[1].title == "Middle")
        #expect(tasks[2].title == "Newest")
    }

    // MARK: - SpreadRepository Tests

    @Test func testSpreadRepositorySaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread()
        try await repository.save(spread)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 1)
        #expect(spreads.first?.id == spread.id)
    }

    @Test func testSpreadRepositorySaveMultipleSpreads() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread1 = DataModel.Spread()
        let spread2 = DataModel.Spread()
        let spread3 = DataModel.Spread()

        try await repository.save(spread1)
        try await repository.save(spread2)
        try await repository.save(spread3)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 3)
    }

    @Test func testSpreadRepositoryDelete() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread()
        try await repository.save(spread)

        var spreads = await repository.getSpreads()
        #expect(spreads.count == 1)

        try await repository.delete(spread)

        spreads = await repository.getSpreads()
        #expect(spreads.count == 0)
    }

    @Test func testSpreadRepositoryReturnsSpreadsSortedByDateDescending() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let now = Date.now
        let spread1 = DataModel.Spread(createdDate: now.addingTimeInterval(-200))
        let spread2 = DataModel.Spread(createdDate: now.addingTimeInterval(-100))
        let spread3 = DataModel.Spread(createdDate: now)

        // Save in non-chronological order
        try await repository.save(spread2)
        try await repository.save(spread1)
        try await repository.save(spread3)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 3)
        // Sorted by date descending (newest first)
        // TODO: SPRD-8 - Update sorting to use period (desc) then date when Period is added
        #expect(spreads[0].createdDate == now)
        #expect(spreads[1].createdDate == now.addingTimeInterval(-100))
        #expect(spreads[2].createdDate == now.addingTimeInterval(-200))
    }

    // MARK: - Repository Isolation Tests

    @Test func testRepositoriesUseIsolatedContainers() async throws {
        let container1 = try ModelContainerFactory.makeForTesting()
        let container2 = try ModelContainerFactory.makeForTesting()

        let taskRepo1 = SwiftDataTaskRepository(modelContainer: container1)
        let taskRepo2 = SwiftDataTaskRepository(modelContainer: container2)

        let task = DataModel.Task(title: "Container 1 Task")
        try await taskRepo1.save(task)

        let tasks1 = await taskRepo1.getTasks()
        let tasks2 = await taskRepo2.getTasks()

        #expect(tasks1.count == 1)
        #expect(tasks2.count == 0)
    }
}
