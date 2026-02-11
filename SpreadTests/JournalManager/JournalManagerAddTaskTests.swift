import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager task creation functionality.
@Suite("JournalManager Add Task Tests")
@MainActor
struct JournalManagerAddTaskTests {

    // MARK: - Test Helpers

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - Task Creation Tests

    /// Tests that adding a task creates it with the correct properties.
    ///
    /// Condition: Add a task with title, date, and period.
    /// Expected: Task is created with provided values, open status, and normalized date.
    @Test("Adding a task creates it with correct properties")
    func testAddTaskCreatesWithCorrectProperties() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        let task = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        #expect(task.title == "Buy groceries")
        #expect(task.period == .day)
        #expect(task.status == .open)
        #expect(calendar.isDate(task.date, inSameDayAs: today))
    }

    /// Tests that adding a task normalizes the date for the selected period.
    ///
    /// Condition: Add a task with month period and mid-month date.
    /// Expected: Task date is normalized to first of the month.
    @Test("Adding a task normalizes date for period")
    func testAddTaskNormalizesDateForPeriod() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let midMonthDate = Self.makeDate(year: 2026, month: 2, day: 17)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        let task = try await journalManager.addTask(
            title: "Monthly review",
            date: midMonthDate,
            period: .month
        )

        // Date should be normalized to first of February
        let expectedDate = Self.makeDate(year: 2026, month: 2, day: 1)
        #expect(calendar.isDate(task.date, inSameDayAs: expectedDate))
    }

    /// Tests that adding a task to a matching spread creates an assignment.
    ///
    /// Condition: Spread exists for the task's period/date.
    /// Expected: Task has an assignment to that spread.
    @Test("Adding a task to matching spread creates assignment")
    func testAddTaskCreatesAssignmentToMatchingSpread() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        // Create a day spread for today
        _ = try await journalManager.addSpread(period: .day, date: today)

        // Add a task for today
        let task = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        // Task should have an assignment
        #expect(task.assignments.count == 1)
        #expect(task.assignments.first?.period == .day)
        #expect(task.assignments.first?.status == .open)
    }

    /// Tests that adding a task without matching spread goes to Inbox.
    ///
    /// Condition: No spread exists for the task's period/date.
    /// Expected: Task has no assignments and appears in Inbox.
    @Test("Adding a task without matching spread goes to Inbox")
    func testAddTaskWithoutMatchingSpreadGoesToInbox() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        // Add a task without creating any spreads
        let task = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        // Task should have no assignments (goes to Inbox)
        #expect(task.assignments.isEmpty)
        #expect(journalManager.inboxCount == 1)
        #expect(journalManager.inboxEntries.contains { ($0 as? DataModel.Task)?.id == task.id })
    }

    /// Tests that adding a task finds the best spread when exact match doesn't exist.
    ///
    /// Condition: Day spread doesn't exist, but month spread does.
    /// Expected: Task is assigned to the month spread.
    @Test("Adding a task finds best spread when exact match unavailable")
    func testAddTaskFindsBestSpreadWhenExactUnavailable() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        // Create only a month spread (no day spread)
        _ = try await journalManager.addSpread(period: .month, date: today)

        // Add a task for today with day period
        let task = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        // Task should be assigned to the month spread (next best match)
        #expect(task.assignments.count == 1)
        #expect(task.assignments.first?.period == .month)
    }

    /// Tests that adding a task increments dataVersion.
    ///
    /// Condition: Add a task.
    /// Expected: dataVersion is incremented for UI refresh.
    @Test("Adding a task increments dataVersion")
    func testAddTaskIncrementsDataVersion() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        let initialVersion = journalManager.dataVersion

        _ = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        #expect(journalManager.dataVersion > initialVersion)
    }

    /// Tests that adding a task persists it to the repository.
    ///
    /// Condition: Add a task.
    /// Expected: Task appears in the tasks list.
    @Test("Adding a task persists it to the tasks list")
    func testAddTaskPersistsToTasksList() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        let task = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        #expect(journalManager.tasks.contains { $0.id == task.id })
    }

    /// Tests that adding a task with year period normalizes correctly.
    ///
    /// Condition: Add a task with year period.
    /// Expected: Task date is normalized to first of the year.
    @Test("Adding a task with year period normalizes to first of year")
    func testAddTaskWithYearPeriodNormalizesToFirstOfYear() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 6, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        let task = try await journalManager.addTask(
            title: "Annual goal",
            date: today,
            period: .year
        )

        // Date should be normalized to first of 2026
        let expectedDate = Self.makeDate(year: 2026, month: 1, day: 1)
        #expect(calendar.isDate(task.date, inSameDayAs: expectedDate))
    }

    /// Tests that task appears in spread data model after creation.
    ///
    /// Condition: Create spread, then add task assigned to it.
    /// Expected: Task appears in the spread's data model.
    @Test("Task appears in spread data model after creation")
    func testTaskAppearsInSpreadDataModel() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)

        let journalManager = try await JournalManager.make(
            calendar: calendar,
            today: today
        )

        // Create a day spread
        let spread = try await journalManager.addSpread(period: .day, date: today)

        // Add a task
        let task = try await journalManager.addTask(
            title: "Buy groceries",
            date: today,
            period: .day
        )

        // Check the spread's data model
        let normalizedDate = Period.day.normalizeDate(spread.date, calendar: calendar)
        let spreadData = journalManager.dataModel[.day]?[normalizedDate]

        #expect(spreadData != nil)
        #expect(spreadData?.tasks.contains { $0.id == task.id } == true)
    }
}
