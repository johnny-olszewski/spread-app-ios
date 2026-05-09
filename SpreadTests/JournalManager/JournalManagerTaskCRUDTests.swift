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

    /// Condition: A caller attempts to set task status to migrated directly.
    /// Expected: The mutation is rejected because migrated is assignment history, not a user-editable task status.
    @Test("Updating task status to migrated is rejected")
    func testUpdateTaskStatusToMigratedThrows() async throws {
        let existingTask = DataModel.Task(
            title: "Migrated guard",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        await #expect(throws: TaskMutationError.manualMigratedStatusNotAllowed) {
            try await manager.updateTaskStatus(existingTask, newStatus: .migrated)
        }
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
        #expect(sourceModel.tasks.contains { $0.id == updatedTask.id } == false)
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

    /// Conditions: A year-assigned task is edited to April 6, 2026 day while only the 2026 year spread and an unrelated January 1 day spread exist.
    /// Expected: The task remains open on the 2026 year spread and does not jump to the unrelated January 1 day spread.
    @Test("Updating a year task to April day falls back to year when no April spread exists")
    @MainActor
    func testUpdateTaskDateAndPeriodFallsBackToYearForMissingAprilSpreads() async throws {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let aprilSixth = calendar.date(from: DateComponents(year: 2026, month: 4, day: 6))!
        let januaryFirstDaySpread = DataModel.Spread(period: .day, date: yearDate, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let existingTask = DataModel.Task(
            title: "Navigator year task",
            createdDate: yearDate,
            date: yearDate,
            period: .year,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: yearDate, status: .open)]
        )

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!,
            taskRepository: InMemoryTaskRepository(tasks: [existingTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, januaryFirstDaySpread])
        )

        try await manager.updateTaskDateAndPeriod(existingTask, newDate: aprilSixth, newPeriod: .day)

        let updatedTask = try #require(manager.tasks.first { $0.id == existingTask.id })
        #expect(updatedTask.date == aprilSixth)
        #expect(updatedTask.period == .day)
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments.first?.matches(period: .year, date: yearDate, calendar: calendar) == true)

        let yearModel = try #require(manager.dataModel[.year]?[yearDate])
        #expect(yearModel.tasks.contains { $0.id == updatedTask.id })

        let januaryDayModel = try #require(manager.dataModel[.day]?[yearDate])
        #expect(januaryDayModel.tasks.contains { $0.id == updatedTask.id } == false)
    }

    // MARK: - Task Metadata Tests

    @Test("Updating task metadata trims body, normalizes due date, and timestamps changed fields")
    @MainActor
    func testUpdateTaskMetadataPersistsNormalizedFields() async throws {
        let calendar = Self.testCalendar
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2, hour: 15))!
        let expectedDueDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let existingTask = DataModel.Task(
            title: "Metadata",
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskMetadata(
            existingTask,
            body: "  Draft details  ",
            priority: .medium,
            dueDate: dueDate
        )

        #expect(existingTask.body == "Draft details")
        #expect(existingTask.priority == .medium)
        #expect(existingTask.dueDate == expectedDueDate)
        #expect(existingTask.bodyUpdatedAt != nil)
        #expect(existingTask.priorityUpdatedAt != nil)
        #expect(existingTask.dueDateUpdatedAt != nil)
    }

    @Test("Clearing task metadata to nil updates nil-able field timestamps")
    @MainActor
    func testUpdateTaskMetadataClearsNilFieldsWithTimestamps() async throws {
        let existingDueDate = Self.testCalendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!
        let existingTask = DataModel.Task(
            title: "Metadata clear",
            body: "Details",
            priority: .high,
            dueDate: existingDueDate,
            createdDate: Self.testDate,
            date: Self.testDate,
            period: .day,
            status: .open
        )
        let manager = try await makeManager(tasks: [existingTask])

        try await manager.updateTaskMetadata(
            existingTask,
            body: " \n ",
            priority: .none,
            dueDate: nil
        )

        #expect(existingTask.body == nil)
        #expect(existingTask.priority == .none)
        #expect(existingTask.dueDate == nil)
        #expect(existingTask.bodyUpdatedAt != nil)
        #expect(existingTask.priorityUpdatedAt != nil)
        #expect(existingTask.dueDateUpdatedAt != nil)
    }

    @Test("Clearing preferred assignment migrates active assignment history")
    @MainActor
    func testClearPreferredAssignmentMigratesActiveAssignment() async throws {
        let calendar = Self.testCalendar
        let sourceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDate, calendar: calendar)
        let existingTask = DataModel.Task(
            title: "Clear assignment",
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

        try await manager.clearTaskPreferredAssignment(
            existingTask,
            fallbackDate: sourceDate,
            fallbackPeriod: .day
        )

        #expect(existingTask.hasPreferredAssignment == false)
        #expect(existingTask.assignments.count == 1)
        #expect(existingTask.assignments.first?.status == .migrated)
        #expect(manager.inboxEntries.contains { ($0 as? DataModel.Task)?.id == existingTask.id })
    }

    @Test("Clearing unmaterialized preferred assignment creates no migrated history")
    @MainActor
    func testClearUnmaterializedPreferredAssignmentCreatesNoHistory() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let existingTask = DataModel.Task(
            title: "Waiting assignment",
            createdDate: today,
            date: today,
            period: .day,
            hasPreferredAssignment: true,
            status: .open,
            assignments: []
        )
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: [existingTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [])
        )

        try await manager.clearTaskPreferredAssignment(
            existingTask,
            fallbackDate: today,
            fallbackPeriod: .day
        )

        #expect(existingTask.hasPreferredAssignment == false)
        #expect(existingTask.assignments.isEmpty)
        #expect(manager.inboxEntries.contains { ($0 as? DataModel.Task)?.id == existingTask.id })
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
