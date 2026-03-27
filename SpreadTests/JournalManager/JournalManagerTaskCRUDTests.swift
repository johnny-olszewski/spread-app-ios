import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager task CRUD operations (update and delete).
@Suite("JournalManager Task CRUD Tests")
@MainActor
struct JournalManagerTaskCRUDTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        TestDataBuilders.testDate
    }

    private func makeManager(
        tasks: [DataModel.Task] = [],
        spreads: [DataModel.Spread] = []
    ) async throws -> JournalManager {
        let calendar = Self.testCalendar
        let today = Self.testDate

        var allSpreads = spreads
        if allSpreads.isEmpty {
            allSpreads = [
                DataModel.Spread(period: .year, date: today, calendar: calendar),
                DataModel.Spread(period: .month, date: today, calendar: calendar),
                DataModel.Spread(period: .day, date: today, calendar: calendar)
            ]
        }

        return try await JournalManager.make(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: tasks),
            spreadRepository: InMemorySpreadRepository(spreads: allSpreads)
        )
    }

    // MARK: - updateTaskTitle Tests

    /// Condition: Update an existing task's title.
    /// Expected: The task's title is changed and persisted.
    @Test("Updating task title persists the change")
    func testUpdateTaskTitlePersistsChange() async throws {
        let existingTask = DataModel.Task(
            title: "Original title",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskTitle(existingTask, newTitle: "Updated title")

        #expect(existingTask.title == "Updated title")
    }

    /// Condition: Update a task's title.
    /// Expected: Data version is incremented.
    @Test("Updating task title increments data version")
    func testUpdateTaskTitleIncrementsDataVersion() async throws {
        let existingTask = DataModel.Task(
            title: "Version test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])
        let initialVersion = manager.dataVersion

        try await manager.updateTaskTitle(existingTask, newTitle: "New title")

        #expect(manager.dataVersion > initialVersion)
    }

    /// Condition: Update a task's title and check the tasks list is refreshed.
    /// Expected: The updated task remains in the manager's tasks list.
    @Test("Updating task title refreshes tasks list")
    func testUpdateTaskTitleRefreshesTasksList() async throws {
        let existingTask = DataModel.Task(
            title: "List refresh test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskTitle(existingTask, newTitle: "Refreshed")

        #expect(manager.tasks.contains { $0.id == existingTask.id })
    }

    // MARK: - updateTaskStatus Tests

    /// Condition: Update a task's status from open to complete.
    /// Expected: The task's status is changed.
    @Test("Updating task status from open to complete")
    func testUpdateTaskStatusOpenToComplete() async throws {
        let existingTask = DataModel.Task(
            title: "Status test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskStatus(existingTask, newStatus: .complete)

        #expect(existingTask.status == .complete)
    }

    /// Condition: Update a task's status from open to cancelled.
    /// Expected: The task's status is changed to cancelled.
    @Test("Updating task status from open to cancelled")
    func testUpdateTaskStatusOpenToCancelled() async throws {
        let existingTask = DataModel.Task(
            title: "Cancel test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskStatus(existingTask, newStatus: .cancelled)

        #expect(existingTask.status == .cancelled)
    }

    /// Condition: Toggle a task's status from complete back to open.
    /// Expected: The task's status is changed back to open.
    @Test("Updating task status from complete back to open")
    func testUpdateTaskStatusCompleteToOpen() async throws {
        let existingTask = DataModel.Task(
            title: "Toggle test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .complete
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskStatus(existingTask, newStatus: .open)

        #expect(existingTask.status == .open)
    }

    /// Condition: Update task status.
    /// Expected: Data version is incremented.
    @Test("Updating task status increments data version")
    func testUpdateTaskStatusIncrementsDataVersion() async throws {
        let existingTask = DataModel.Task(
            title: "Version test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])
        let initialVersion = manager.dataVersion

        try await manager.updateTaskStatus(existingTask, newStatus: .complete)

        #expect(manager.dataVersion > initialVersion)
    }

    // MARK: - updateTaskDateAndPeriod Tests

    /// Condition: Update a task's date and period from day to month.
    /// Expected: The task's date is normalized to the month start and period is changed.
    @Test("Updating task date and period normalizes date")
    func testUpdateTaskDateAndPeriodNormalizesDate() async throws {
        let existingTask = DataModel.Task(
            title: "Date change test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])
        let calendar = Self.testCalendar
        let newDate = calendar.date(byAdding: .month, value: 1, to: Self.testDate)!

        try await manager.updateTaskDateAndPeriod(
            existingTask,
            newDate: newDate,
            newPeriod: .month
        )

        #expect(existingTask.period == .month)
        // Date should be normalized to month start
        let normalizedDate = Period.month.normalizeDate(newDate, calendar: calendar)
        #expect(existingTask.date == normalizedDate)
    }

    /// Condition: Update a task's date and period.
    /// Expected: Data version is incremented.
    @Test("Updating task date and period increments data version")
    func testUpdateTaskDateAndPeriodIncrementsDataVersion() async throws {
        let existingTask = DataModel.Task(
            title: "Version test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])
        let initialVersion = manager.dataVersion

        try await manager.updateTaskDateAndPeriod(
            existingTask,
            newDate: Self.testDate,
            newPeriod: .year
        )

        #expect(manager.dataVersion > initialVersion)
    }

    /// Condition: Update a task's period from day to year.
    /// Expected: The task's date is normalized to the year start.
    @Test("Updating task to year period normalizes to year start")
    func testUpdateTaskToYearPeriodNormalizesToYearStart() async throws {
        let existingTask = DataModel.Task(
            title: "Year normalize test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])
        let calendar = Self.testCalendar

        try await manager.updateTaskDateAndPeriod(
            existingTask,
            newDate: Self.testDate,
            newPeriod: .year
        )

        let normalizedDate = Period.year.normalizeDate(Self.testDate, calendar: calendar)
        #expect(existingTask.date == normalizedDate)
        #expect(existingTask.period == .year)
    }

    /// Condition: An open task changes to a new date with a matching conventional spread.
    /// Expected: The previous live assignment is marked migrated and the new spread becomes open.
    @Test("Updating task date and period reassigns the live spread")
    @MainActor
    func testUpdateTaskDateAndPeriodReassignsLiveAssignment() async throws {
        let calendar = Self.testCalendar
        let sourceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let destinationDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20))!
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDate, calendar: calendar)
        let destinationSpread = DataModel.Spread(period: .day, date: destinationDate, calendar: calendar)
        let existingTask = DataModel.Task(
            title: "Reassign me",
            createdDate: sourceDate,
            date: sourceDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: sourceDate, status: .open)]
        )
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: sourceDate,
            taskRepository: InMemoryTaskRepository(tasks: [existingTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [sourceSpread, destinationSpread])
        )

        try await manager.updateTaskDateAndPeriod(existingTask, newDate: destinationDate, newPeriod: .day)

        let updatedTask = try #require(manager.tasks.first { $0.id == existingTask.id })
        #expect(updatedTask.date == destinationDate)
        #expect(updatedTask.assignments.count == 2)
        #expect(updatedTask.assignments.first(where: { $0.matches(period: .day, date: sourceDate, calendar: calendar) })?.status == .migrated)
        #expect(updatedTask.assignments.first(where: { $0.matches(period: .day, date: destinationDate, calendar: calendar) })?.status == .open)

        let sourceModel = try #require(manager.dataModel[.day]?[sourceDate])
        let destinationModel = try #require(manager.dataModel[.day]?[destinationDate])
        #expect(sourceModel.tasks.contains { $0.id == updatedTask.id })
        #expect(destinationModel.tasks.contains { $0.id == updatedTask.id })
    }

    /// Condition: An open task changes to a date without a matching spread.
    /// Expected: Existing live assignments become migrated and the task returns to Inbox.
    @Test("Updating task date and period can move task back to Inbox")
    @MainActor
    func testUpdateTaskDateAndPeriodCanMoveTaskToInbox() async throws {
        let calendar = Self.testCalendar
        let sourceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let destinationDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDate, calendar: calendar)
        let existingTask = DataModel.Task(
            title: "Inbox me",
            createdDate: sourceDate,
            date: sourceDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: sourceDate, status: .open)]
        )
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: sourceDate,
            taskRepository: InMemoryTaskRepository(tasks: [existingTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [sourceSpread])
        )

        try await manager.updateTaskDateAndPeriod(existingTask, newDate: destinationDate, newPeriod: .day)

        let updatedTask = try #require(manager.tasks.first { $0.id == existingTask.id })
        #expect(updatedTask.date == destinationDate)
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments.first?.status == .migrated)
        #expect(manager.inboxEntries.contains { $0.id == existingTask.id })
    }

    // MARK: - deleteTask Tests

    /// Condition: Delete an existing task.
    /// Expected: Task is removed from the tasks list.
    @Test("Deleting a task removes it from the list")
    func testDeleteTaskRemovesFromList() async throws {
        let existingTask = DataModel.Task(
            title: "Delete me",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        #expect(manager.tasks.contains { $0.id == existingTask.id })

        try await manager.deleteTask(existingTask)

        #expect(!manager.tasks.contains { $0.id == existingTask.id })
    }

    /// Condition: Delete a task and check data version.
    /// Expected: Data version is incremented.
    @Test("Deleting a task increments data version")
    func testDeleteTaskIncrementsDataVersion() async throws {
        let existingTask = DataModel.Task(
            title: "Delete version test",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])
        let initialVersion = manager.dataVersion

        try await manager.deleteTask(existingTask)

        #expect(manager.dataVersion > initialVersion)
    }

    /// Condition: Delete one of several tasks.
    /// Expected: Only the targeted task is removed; others remain.
    @Test("Deleting a task leaves other tasks intact")
    func testDeleteTaskLeavesOtherTasksIntact() async throws {
        let task1 = DataModel.Task(
            title: "Keep me",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let task2 = DataModel.Task(
            title: "Delete me",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [task1, task2])

        try await manager.deleteTask(task2)

        #expect(manager.tasks.contains { $0.id == task1.id })
        #expect(!manager.tasks.contains { $0.id == task2.id })
    }

    // MARK: - Data Model Integration

    /// Condition: Update a task's status and check the data model.
    /// Expected: The data model reflects the updated status.
    @Test("Updated task status is reflected in data model")
    func testUpdatedTaskStatusReflectedInDataModel() async throws {
        let calendar = Self.testCalendar
        let dayDate = Period.day.normalizeDate(Self.testDate, calendar: calendar)

        let existingTask = DataModel.Task(
            title: "Data model task",
            createdDate: Self.testDate,
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: dayDate, status: .open)
            ]
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskStatus(existingTask, newStatus: .complete)

        let dayDataModel = manager.dataModel[.day]?[dayDate]
        let modelTask = dayDataModel?.tasks.first { $0.id == existingTask.id }
        #expect(modelTask?.status == .complete)
    }

    /// Condition: Delete a task and check the data model.
    /// Expected: The task no longer appears in the data model.
    @Test("Deleted task is removed from data model")
    func testDeletedTaskRemovedFromDataModel() async throws {
        let calendar = Self.testCalendar
        let dayDate = Period.day.normalizeDate(Self.testDate, calendar: calendar)

        let existingTask = DataModel.Task(
            title: "Remove from model",
            createdDate: Self.testDate,
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: dayDate, status: .open)
            ]
        )
        let manager = try await makeManager(tasks: [existingTask])

        // Verify task is in data model before deletion
        let dayDataModelBefore = manager.dataModel[.day]?[dayDate]
        #expect(dayDataModelBefore?.tasks.contains { $0.id == existingTask.id } == true)

        try await manager.deleteTask(existingTask)

        let dayDataModelAfter = manager.dataModel[.day]?[dayDate]
        #expect(dayDataModelAfter?.tasks.contains { $0.id == existingTask.id } != true)
    }
}
