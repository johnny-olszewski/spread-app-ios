import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.UUID
import Testing
@testable import Spread

@Suite(.serialized)
struct CancelledTaskTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Spread Entry List Tests

    /// Conditions: A cancelled task has an assignment matching an existing spread.
    /// Expected: The spread's task list excludes the cancelled task.
    @Test @MainActor func testSpreadEntryListExcludesCancelledTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        // Create spread
        let spread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Create cancelled task with assignment to the spread
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .cancelled)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        // Get tasks for the spread via dataModel
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
        let spreadData = manager.dataModel[spread.period]?[normalizedDate]

        #expect(spreadData != nil)
        #expect(spreadData?.tasks.isEmpty == true)
    }

    /// Conditions: A spread has both open and cancelled tasks with assignments.
    /// Expected: Only open tasks appear in the spread's task list.
    @Test @MainActor func testSpreadEntryListIncludesOpenTasksExcludesCancelledTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        // Create spread
        let spread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Create open task
        let openTask = DataModel.Task(
            title: "Open Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .open)
            ]
        )

        // Create cancelled task
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .cancelled)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [openTask, cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        // Get tasks for the spread via dataModel
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
        let spreadData = manager.dataModel[spread.period]?[normalizedDate]

        #expect(spreadData?.tasks.count == 1)
        #expect(spreadData?.tasks.first?.id == openTask.id)
    }

    /// Conditions: A cancelled task has an assignment to a month spread.
    /// Expected: The month spread's task list excludes the cancelled task.
    @Test @MainActor func testMonthSpreadExcludesCancelledTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        // Create month spread
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)

        // Create cancelled task with month assignment
        let cancelledTask = DataModel.Task(
            title: "Cancelled Monthly Task",
            date: taskDate,
            period: .month,
            status: .cancelled,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .cancelled)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let normalizedDate = monthSpread.period.normalizeDate(monthSpread.date, calendar: calendar)
        let spreadData = manager.dataModel[monthSpread.period]?[normalizedDate]

        #expect(spreadData?.tasks.isEmpty == true)
    }

    /// Conditions: A cancelled task has a preferred date within a multiday spread's range.
    /// Expected: The multiday spread excludes the cancelled task.
    @Test @MainActor func testMultidaySpreadExcludesCancelledTasks() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let taskDate = Self.testDate // Jan 15, within the multiday range

        // Create multiday spread using startDate/endDate initializer
        let multidaySpread = DataModel.Spread(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        // Create cancelled task with date in range
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task in Range",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: []
        )

        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [multidaySpread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let spreadData = manager.dataModel[.multiday]?[multidaySpread.date]

        #expect(spreadData?.tasks.isEmpty == true)
    }

    // MARK: - Database Retention Tests

    /// Conditions: A cancelled task exists in the repository.
    /// Expected: The task remains accessible via the tasks property.
    @Test @MainActor func testCancelledTasksRemainInDatabase() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: []
        )

        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo
        )

        // Task should still be in the raw tasks array for potential restore
        #expect(manager.tasks.count == 1)
        #expect(manager.tasks.first?.id == cancelledTask.id)
        #expect(manager.tasks.first?.status == .cancelled)
    }

    /// Conditions: Multiple tasks exist with various statuses.
    /// Expected: All tasks remain in the tasks property regardless of status.
    @Test @MainActor func testAllTaskStatusesRemainInDatabase() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let openTask = DataModel.Task(
            title: "Open Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: []
        )

        let completedTask = DataModel.Task(
            title: "Completed Task",
            date: taskDate,
            period: .day,
            status: .complete,
            assignments: []
        )

        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: []
        )

        let taskRepo = InMemoryTaskRepository(tasks: [openTask, completedTask, cancelledTask])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo
        )

        #expect(manager.tasks.count == 3)
    }

    // MARK: - Completed Task Tests (Non-Cancelled Visible)

    /// Conditions: A completed task has an assignment matching an existing spread.
    /// Expected: The completed task appears in the spread's task list.
    @Test @MainActor func testSpreadEntryListIncludesCompletedTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        // Create spread
        let spread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Create completed task
        let completedTask = DataModel.Task(
            title: "Completed Task",
            date: taskDate,
            period: .day,
            status: .complete,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .complete)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [completedTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
        let spreadData = manager.dataModel[spread.period]?[normalizedDate]

        #expect(spreadData?.tasks.count == 1)
        #expect(spreadData?.tasks.first?.id == completedTask.id)
    }

    /// Conditions: A migrated task has an assignment matching an existing spread.
    /// Expected: The migrated task appears in the spread's task list.
    @Test @MainActor func testSpreadEntryListIncludesMigratedTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        // Create spread
        let spread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Create migrated task
        let migratedTask = DataModel.Task(
            title: "Migrated Task",
            date: taskDate,
            period: .day,
            status: .migrated,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .migrated)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [migratedTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
        let spreadData = manager.dataModel[spread.period]?[normalizedDate]

        #expect(spreadData?.tasks.count == 1)
        #expect(spreadData?.tasks.first?.id == migratedTask.id)
    }
}
