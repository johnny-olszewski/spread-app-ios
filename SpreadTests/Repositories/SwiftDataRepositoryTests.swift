import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.TimeZone
import SwiftData
import Testing
@testable import Spread

/// Integration tests for SwiftData repository implementations.
///
/// Tests CRUD operations using in-memory containers for isolation.
@MainActor
struct SwiftDataRepositoryTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

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

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 1)
        #expect(spreads.first?.id == spread.id)
    }

    @Test func testSpreadRepositorySaveMultipleSpreads() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let now = Date.now
        let spread1 = DataModel.Spread(period: .year, date: now, calendar: testCalendar)
        let spread2 = DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        let spread3 = DataModel.Spread(period: .day, date: now, calendar: testCalendar)

        try await repository.save(spread1)
        try await repository.save(spread2)
        try await repository.save(spread3)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 3)
    }

    @Test func testSpreadRepositoryDelete() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        var spreads = await repository.getSpreads()
        #expect(spreads.count == 1)

        try await repository.delete(spread)

        spreads = await repository.getSpreads()
        #expect(spreads.count == 0)
    }

    @Test func testSpreadRepositoryReturnsSortedByPeriodThenDateDescending() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let now = Date.now
        // Create spreads of different periods
        let daySpread1 = DataModel.Spread(period: .day, date: now, calendar: testCalendar)
        let daySpread2 = DataModel.Spread(
            period: .day,
            date: now.addingTimeInterval(-86400),
            calendar: testCalendar
        )
        let monthSpread = DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        let yearSpread = DataModel.Spread(period: .year, date: now, calendar: testCalendar)

        // Save in random order
        try await repository.save(daySpread2)
        try await repository.save(monthSpread)
        try await repository.save(daySpread1)
        try await repository.save(yearSpread)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 4)
        // Sorted by period (year > month > day), then by date descending
        #expect(spreads[0].period == .year)
        #expect(spreads[1].period == .month)
        #expect(spreads[2].period == .day)
        #expect(spreads[3].period == .day)
        // Same period: should be sorted by date descending
        #expect(spreads[2].date > spreads[3].date)
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
