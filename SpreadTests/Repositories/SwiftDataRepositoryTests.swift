import Foundation
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

    /// Conditions: Save a task to an empty SwiftData task repository.
    /// Expected: Fetching tasks returns one task with the saved title.
    @Test func testTaskRepositorySaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Test Task")
        try await repository.save(task)

        let tasks = await repository.getTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Test Task")
    }

    /// Conditions: Save three tasks to the repository.
    /// Expected: Fetching tasks returns three tasks.
    @Test func testTaskRepositorySaveMultipleTasks() async throws {
        let container = try ModelContainerFactory.makeInMemory()
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

    /// Conditions: Save a task, then delete it.
    /// Expected: Fetching tasks returns an empty list.
    @Test func testTaskRepositoryDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Task to Delete")
        try await repository.save(task)

        var tasks = await repository.getTasks()
        #expect(tasks.count == 1)

        try await repository.delete(task)

        tasks = await repository.getTasks()
        #expect(tasks.count == 0)
    }

    /// Conditions: Save a task, update its title, and save again.
    /// Expected: Repository has one task with the updated title.
    @Test func testTaskRepositoryUpdateExistingTask() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataTaskRepository(modelContainer: container)

        let task = DataModel.Task(title: "Original Title")
        try await repository.save(task)

        task.title = "Updated Title"
        try await repository.save(task)

        let tasks = await repository.getTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Updated Title")
    }

    /// Conditions: Save tasks with different created dates in non-chronological order.
    /// Expected: Fetching tasks returns them sorted by date ascending.
    @Test func testTaskRepositoryReturnsTasksSortedByDateAscending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
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

    /// Conditions: Save a task with sync enabled.
    /// Expected: An outbox mutation is created with device ID and create operation.
    @Test func testTaskRepositorySaveEnqueuesCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        let task = DataModel.Task(title: "Sync Task")
        try await repository.save(task)

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.task.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save a task with an initial spread assignment.
    /// Expected: Parent task mutation is enqueued before a child task-assignment create mutation.
    @Test func testTaskRepositorySaveEnqueuesAssignmentCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 110) }
        )

        let assignment = TaskAssignment(
            period: .day,
            date: Date(timeIntervalSince1970: 1_000),
            status: .open
        )
        let task = DataModel.Task(title: "Assigned task", assignments: [assignment])

        try await repository.save(task)

        let mutations = try fetchMutations(from: container)
        #expect(mutations.map(\.entityType) == [
            SyncEntityType.task.rawValue,
            SyncEntityType.taskAssignment.rawValue
        ])

        let assignmentMutation = mutations.last
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(assignmentMutation?.recordData)
        #expect(record?["task_id"] as? String == task.id.uuidString)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
        #expect(record?["deleted_at"] is NSNull)
    }

    /// Conditions: Save a task, then save again after updating its title.
    /// Expected: An update mutation is enqueued in the outbox.
    @Test func testTaskRepositoryUpdateEnqueuesUpdateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 200) }
        )

        let task = DataModel.Task(title: "Original")
        try await repository.save(task)

        task.title = "Updated"
        try await repository.save(task)

        let operations = try fetchMutations(from: container).map { $0.operation }

        #expect(operations.contains(SyncOperation.update.rawValue))
    }

    /// Conditions: Save a task, then change its assignment status and save again.
    /// Expected: A task-assignment update mutation is enqueued for the same logical assignment.
    @Test func testTaskRepositoryUpdateEnqueuesAssignmentUpdateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let assignmentDate = Date(timeIntervalSince1970: 2_000)
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 210) }
        )

        let assignment = TaskAssignment(period: .day, date: assignmentDate, status: .open)
        let task = DataModel.Task(title: "Assigned task", assignments: [assignment])
        try await repository.save(task)

        task.assignments[0].status = .complete
        try await repository.save(task)

        let mutations = try fetchMutations(from: container)
        let assignmentUpdate = mutations.last {
            $0.entityType == SyncEntityType.taskAssignment.rawValue &&
            $0.operation == SyncOperation.update.rawValue
        }

        #expect(assignmentUpdate != nil)
        #expect(assignmentUpdate?.entityId == assignment.id)

        let record = try decodeRecord(assignmentUpdate?.recordData)
        #expect(record?["status"] as? String == DataModel.Task.Status.complete.rawValue)
        #expect(record?["deleted_at"] is NSNull)
    }

    /// Conditions: Save a task, then delete it.
    /// Expected: A delete mutation is enqueued with deleted_at set.
    @Test func testTaskRepositoryDeleteEnqueuesDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        var timestamps = [
            Date(timeIntervalSince1970: 300),
            Date(timeIntervalSince1970: 400)
        ]
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { timestamps.removeFirst() }
        )

        let task = DataModel.Task(title: "Delete Me")
        try await repository.save(task)
        try await repository.delete(task)

        let mutations = try fetchMutations(from: container)
        let deleteMutation = mutations.last(where: { $0.operation == SyncOperation.delete.rawValue })

        #expect(deleteMutation != nil)

        let record = try decodeRecord(deleteMutation?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 400)))
    }

    /// Conditions: Save a task with an assignment, then delete the task.
    /// Expected: A task-assignment delete mutation is enqueued as a tombstone.
    @Test func testTaskRepositoryDeleteEnqueuesAssignmentDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [
            Date(timeIntervalSince1970: 500),
            Date(timeIntervalSince1970: 600)
        ]
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = TaskAssignment(
            period: .month,
            date: Date(timeIntervalSince1970: 3_000),
            status: .open
        )
        let task = DataModel.Task(title: "Delete assigned task", assignments: [assignment])
        try await repository.save(task)
        try await repository.delete(task)

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.taskAssignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)

        let record = try decodeRecord(assignmentDelete?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 600)))
    }

    /// Conditions: Save a task with an assignment, clear assignments, and save again.
    /// Expected: A task-assignment tombstone is enqueued even though the parent task remains.
    @Test func testTaskRepositoryUpdateEnqueuesAssignmentDeleteWhenAssignmentRemoved() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [
            Date(timeIntervalSince1970: 700),
            Date(timeIntervalSince1970: 800)
        ]
        let repository = SwiftDataTaskRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = TaskAssignment(
            period: .day,
            date: Date(timeIntervalSince1970: 4_000),
            status: .open
        )
        let task = DataModel.Task(title: "Inbox fallback", assignments: [assignment])
        try await repository.save(task)

        task.assignments.removeAll()
        try await repository.save(task)

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.taskAssignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)

        let record = try decodeRecord(assignmentDelete?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 800)))
    }

    // MARK: - SpreadRepository Tests

    /// Conditions: Save a spread to an empty SwiftData spread repository.
    /// Expected: Fetching spreads returns one spread with the same id.
    @Test func testSpreadRepositorySaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 1)
        #expect(spreads.first?.id == spread.id)
    }

    /// Conditions: Save a spread with sync enabled.
    /// Expected: An outbox mutation is created with device ID and create operation.
    @Test func testSpreadRepositorySaveEnqueuesCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataSpreadRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 500) }
        )

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.spread.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save three spreads to the repository.
    /// Expected: Fetching spreads returns three spreads.
    @Test func testSpreadRepositorySaveMultipleSpreads() async throws {
        let container = try ModelContainerFactory.makeInMemory()
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

    /// Conditions: Save a spread, then delete it.
    /// Expected: Fetching spreads returns an empty list.
    @Test func testSpreadRepositoryDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        var spreads = await repository.getSpreads()
        #expect(spreads.count == 1)

        try await repository.delete(spread)

        spreads = await repository.getSpreads()
        #expect(spreads.count == 0)
    }

    /// Conditions: Save a spread, then delete it.
    /// Expected: A delete mutation is enqueued with deleted_at set.
    @Test func testSpreadRepositoryDeleteEnqueuesDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        var timestamps = [
            Date(timeIntervalSince1970: 600),
            Date(timeIntervalSince1970: 700)
        ]
        let repository = SwiftDataSpreadRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { timestamps.removeFirst() }
        )

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)
        try await repository.delete(spread)

        let mutations = try fetchMutations(from: container)
        let deleteMutation = mutations.last(where: { $0.operation == SyncOperation.delete.rawValue })

        #expect(deleteMutation != nil)

        let record = try decodeRecord(deleteMutation?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 700)))
    }

    /// Conditions: Save spreads of different periods and dates in random order.
    /// Expected: Fetching spreads returns period order (year, month, day), then date descending.
    @Test func testSpreadRepositoryReturnsSortedByPeriodThenDateDescending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
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

    /// Conditions: Save a task in a repository backed by one container and read from another.
    /// Expected: First repository has the task, second repository is empty.
    @Test func testRepositoriesUseIsolatedContainers() async throws {
        let container1 = try ModelContainerFactory.makeInMemory()
        let container2 = try ModelContainerFactory.makeInMemory()

        let taskRepo1 = SwiftDataTaskRepository(modelContainer: container1)
        let taskRepo2 = SwiftDataTaskRepository(modelContainer: container2)

        let task = DataModel.Task(title: "Container 1 Task")
        try await taskRepo1.save(task)

        let tasks1 = await taskRepo1.getTasks()
        let tasks2 = await taskRepo2.getTasks()

        #expect(tasks1.count == 1)
        #expect(tasks2.count == 0)
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
