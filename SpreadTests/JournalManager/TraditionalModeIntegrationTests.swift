import Foundation
import Testing
@testable import Spread

/// Integration tests for traditional mode mapping.
///
/// Validates that traditional mode operations (virtual spread generation,
/// migration, data model building) never mutate created spread records,
/// and that fallback to parent or Inbox works correctly.
struct TraditionalModeIntegrationTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        testCalendar.date(from: .init(year: year, month: month, day: day))!
    }

    // MARK: - No Spread Mutation

    /// Traditional data model building must not create or modify spread records.
    /// Setup: JournalManager in traditional mode with tasks but no spreads.
    /// Expected: After loadData, spreads array remains empty; dataModel has virtual entries.
    @Test @MainActor func testTraditionalDataModelDoesNotCreateSpreads() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository()

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        // Spreads remain empty — no spread records created
        #expect(manager.spreads.isEmpty)

        // But data model should have virtual spread data for the day
        #expect(manager.dataModel[.day] != nil)
    }

    /// Traditional migration must not add new spread records.
    /// Setup: JournalManager in traditional mode with one spread and one task.
    /// Action: Migrate task to a different date.
    /// Expected: Spread count remains unchanged.
    @Test @MainActor func testTraditionalMigrationDoesNotCreateSpreads() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let monthSpread = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        let spreadCountBefore = manager.spreads.count
        try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)

        // Spread count must not change
        #expect(manager.spreads.count == spreadCountBefore)
    }

    /// Traditional explicit spread creation must not auto-reconcile inbox entries.
    /// Setup: JournalManager in traditional mode with inbox task and note, then create a matching day spread.
    /// Expected: Explicit spread is saved, but task and note remain unassigned because automatic migration is conventional-only.
    @Test @MainActor func testTraditionalAddSpreadDoesNotAutoReconcileInboxEntries() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 15)
        let task = DataModel.Task(
            title: "Inbox Task",
            date: dayDate,
            period: .day,
            hasPreferredAssignment: true,
            assignments: []
        )
        let note = DataModel.Note(
            title: "Inbox Note",
            date: dayDate,
            period: .day,
            assignments: []
        )

        let manager = try await JournalManager.make(
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            noteRepository: InMemoryNoteRepository(notes: [note]),
            bujoMode: .traditional
        )

        let spread = try await manager.addSpread(period: Period.day, date: dayDate)

        #expect(manager.spreads.count == 1)
        #expect(manager.spreads.first?.id == spread.id)
        let updatedTask = try #require(manager.tasks.first { $0.id == task.id })
        let updatedNote = try #require(manager.notes.first { $0.id == note.id })
        #expect(updatedTask.assignments.isEmpty)
        #expect(updatedNote.assignments.isEmpty)
        #expect(manager.inboxEntries.count == 2)
    }

    /// Traditional migration must not modify existing spread records.
    /// Setup: One month spread. Migrate a task to a date within that month.
    /// Expected: Spread's period, date, and id remain unchanged.
    @Test @MainActor func testTraditionalMigrationDoesNotModifySpreads() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan20 = Self.makeDate(year: 2026, month: 1, day: 20)
        let monthSpread = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let originalSpreadId = monthSpread.id
        let originalSpreadDate = monthSpread.date
        let originalSpreadPeriod = monthSpread.period

        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: jan20, newPeriod: .day)

        // Verify spread is unchanged
        let spread = manager.spreads[0]
        #expect(spread.id == originalSpreadId)
        #expect(spread.date == originalSpreadDate)
        #expect(spread.period == originalSpreadPeriod)
    }

    // MARK: - Migration with Conventional Spread Fallback

    /// Migration to a date matching a conventional day spread assigns to that spread.
    /// Setup: Day spread for Jan 20, task on Jan 15.
    /// Action: Migrate task to Jan 20 with period .day.
    /// Expected: Task gets assignment on the day spread.
    @Test @MainActor func testMigrationAssignsToMatchingDaySpread() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan20 = Self.makeDate(year: 2026, month: 1, day: 20)
        let daySpread = DataModel.Spread(
            period: .day,
            date: jan20,
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: jan20, newPeriod: .day)

        // Task should have one assignment on the day spread
        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments[0].period == .day)
        #expect(updatedTask.date == jan20)
    }

    /// Migration to a date with only a month spread falls back to the month.
    /// Setup: Month spread for January, no day spread for Jan 20.
    /// Action: Migrate task to Jan 20 with period .day.
    /// Expected: Task gets assignment on the month spread (parent fallback).
    @Test @MainActor func testMigrationFallsBackToMonthSpread() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan20 = Self.makeDate(year: 2026, month: 1, day: 20)
        let monthSpread = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: jan20, newPeriod: .day)

        // Task should fall back to month spread
        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments[0].period == .month)
    }

    /// Migration to a date with only a year spread falls back to the year.
    /// Setup: Year spread for 2026, no month or day spread.
    /// Action: Migrate task to Feb 10.
    /// Expected: Task gets assignment on the year spread.
    @Test @MainActor func testMigrationFallsBackToYearSpread() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let yearSpread = DataModel.Spread(
            period: .year,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)

        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments[0].period == .year)
    }

    /// Migration with no conventional spreads sends the task to Inbox.
    /// Setup: No spreads at all.
    /// Action: Migrate task to a new date.
    /// Expected: Task has no assignments (Inbox).
    @Test @MainActor func testMigrationToInboxWhenNoSpreadsExist() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)

        // No assignment — task goes to Inbox
        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.isEmpty)
        #expect(manager.inboxCount > 0)
    }

    /// Migration with a spread in a different year sends the task to Inbox.
    /// Setup: Year spread for 2025, migrate to a date in 2026.
    /// Expected: Task has no assignments (Inbox) — wrong year.
    @Test @MainActor func testMigrationToInboxWhenSpreadDoesNotMatch() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let yearSpread2025 = DataModel.Spread(
            period: .year,
            date: Self.makeDate(year: 2025, month: 1),
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread2025])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)

        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.isEmpty)
    }

    // MARK: - Note Migration

    /// Traditional note migration assigns to a matching conventional spread.
    /// Setup: Month spread for January, note on Jan 15.
    /// Action: Migrate note to Jan 20.
    /// Expected: Note gets active assignment on the month spread.
    @Test @MainActor func testNoteMigrationAssignsToSpread() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan20 = Self.makeDate(year: 2026, month: 1, day: 20)
        let monthSpread = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let note = DataModel.Note(title: "Test Note", date: jan15, period: .day)
        let noteRepo = InMemoryNoteRepository(notes: [note])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.make(
            spreadRepository: spreadRepo,
            noteRepository: noteRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateNote(note, newDate: jan20, newPeriod: .day)

        let updatedNote = manager.notes.first { $0.id == note.id }!
        #expect(updatedNote.assignments.count == 1)
        #expect(updatedNote.assignments[0].status == .active)
        #expect(updatedNote.assignments[0].period == .month)
    }

    /// Traditional note migration to Inbox when no spread exists.
    /// Setup: No spreads.
    /// Action: Migrate note.
    /// Expected: Note has no assignments.
    @Test @MainActor func testNoteMigrationToInbox() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let note = DataModel.Note(title: "Test Note", date: jan15, period: .day)
        let noteRepo = InMemoryNoteRepository(notes: [note])

        let manager = try await JournalManager.make(
            noteRepository: noteRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateNote(note, newDate: feb10, newPeriod: .day)

        let updatedNote = manager.notes.first { $0.id == note.id }!
        #expect(updatedNote.assignments.isEmpty)
    }

    // MARK: - Traditional Migration Updates Preferred Date/Period

    /// Migration updates the task's preferred date and period.
    /// Setup: Task with day period on Jan 15.
    /// Action: Migrate to Feb 10 with month period.
    /// Expected: Task's date and period are updated.
    @Test @MainActor func testMigrationUpdatesTaskPreferences() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb1 = Self.makeDate(year: 2026, month: 2)
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: feb1, newPeriod: .month)

        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.period == .month)
        // Date should be normalized to the first of the month
        let month = Self.testCalendar.component(.month, from: updatedTask.date)
        #expect(month == 2)
    }

    /// Migration clears old assignments before creating new ones.
    /// Setup: Task with an existing assignment, migrate to a new date.
    /// Expected: Old assignments are cleared, only new assignment exists.
    @Test @MainActor func testMigrationClearsOldAssignments() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let monthSpreadJan = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let monthSpreadFeb = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 2),
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        // Pre-assign to January month
        task.assignments = [
            TaskAssignment(
                period: .month,
                date: Self.makeDate(year: 2026, month: 1),
                status: .open
            )
        ]
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpreadJan, monthSpreadFeb])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)

        // Only one assignment (February), no old January assignment
        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.count == 1)
        let assignmentMonth = Self.testCalendar.component(.month, from: updatedTask.assignments[0].date)
        #expect(assignmentMonth == 2)
    }

    // MARK: - Virtual Spread Data Model

    /// Traditional data model generates virtual spreads at year, month, and day levels.
    /// Setup: Tasks on different days in different months.
    /// Expected: Data model contains virtual spreads at all three levels.
    @Test @MainActor func testTraditionalDataModelGeneratesAllLevels() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let task1 = DataModel.Task(title: "Task 1", date: jan15, period: .day)
        let task2 = DataModel.Task(title: "Task 2", date: feb10, period: .day)
        let taskRepo = InMemoryTaskRepository(tasks: [task1, task2])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            bujoMode: .traditional
        )

        // Year level should exist
        #expect(manager.dataModel[.year] != nil)
        #expect(manager.dataModel[.year]?.count == 1) // 2026

        // Month level should have 2 months
        #expect(manager.dataModel[.month] != nil)
        #expect(manager.dataModel[.month]?.count == 2) // Jan, Feb

        // Day level should have 2 days
        #expect(manager.dataModel[.day] != nil)
        #expect(manager.dataModel[.day]?.count == 2) // Jan 15, Feb 10
    }

    /// Virtual year spreads are generated as containers without inheriting day-period entries.
    /// Setup: Two day-period tasks in the same year.
    /// Expected: Year-level virtual spread exists, but day-period tasks remain on their exact preferred day spreads.
    @Test @MainActor func testYearLevelVirtualSpreadDoesNotAggregateDayEntries() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let task1 = DataModel.Task(title: "Task 1", date: jan15, period: .day)
        let task2 = DataModel.Task(title: "Task 2", date: feb10, period: .day)
        let taskRepo = InMemoryTaskRepository(tasks: [task1, task2])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            bujoMode: .traditional
        )

        let yearDate = Period.year.normalizeDate(jan15, calendar: Self.testCalendar)
        let yearModel = manager.dataModel[.year]?[yearDate]
        #expect(yearModel != nil)
        #expect(yearModel?.tasks.count == 0)
    }

    /// Data model rebuild after migration reflects updated virtual spreads.
    /// Setup: Task on Jan 15, migrate to Feb 10 (no conventional spreads).
    /// Expected: Data model no longer has Jan 15 day spread, has Feb 10 instead.
    @Test @MainActor func testDataModelRebuildAfterMigration() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let task = DataModel.Task(title: "Test Task", date: jan15, period: .day, status: .open)
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            bujoMode: .traditional
        )

        // Before migration: Jan 15 exists in data model
        let jan15Normalized = Period.day.normalizeDate(jan15, calendar: Self.testCalendar)
        #expect(manager.dataModel[.day]?[jan15Normalized] != nil)

        try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)

        // After migration: Jan 15 gone, Feb 10 exists
        #expect(manager.dataModel[.day]?[jan15Normalized] == nil)
        let feb10Normalized = Period.day.normalizeDate(feb10, calendar: Self.testCalendar)
        #expect(manager.dataModel[.day]?[feb10Normalized] != nil)
    }

    // MARK: - Completed Task Migration

    /// Migrating a completed task preserves the complete status in the assignment.
    /// Setup: Completed task with period .day.
    /// Action: Migrate to a date with a matching spread.
    /// Expected: Assignment status is .complete (not .open).
    @Test @MainActor func testCompletedTaskMigrationPreservesStatus() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan20 = Self.makeDate(year: 2026, month: 1, day: 20)
        let monthSpread = DataModel.Spread(
            period: .month,
            date: Self.makeDate(year: 2026, month: 1),
            calendar: Self.testCalendar
        )
        let task = DataModel.Task(title: "Done Task", date: jan15, period: .day, status: .complete)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            bujoMode: .traditional
        )

        try await manager.traditionalMigrateTask(task, newDate: jan20, newPeriod: .day)

        let updatedTask = manager.tasks.first { $0.id == task.id }!
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments[0].status == .complete)
    }

    /// Migrating a cancelled task throws an error.
    /// Setup: Cancelled task.
    /// Action: Attempt migration.
    /// Expected: MigrationError.taskCancelled is thrown.
    @Test @MainActor func testCancelledTaskMigrationThrows() async throws {
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let task = DataModel.Task(title: "Cancelled", date: jan15, period: .day, status: .cancelled)
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.make(
            taskRepository: taskRepo,
            bujoMode: .traditional
        )

        await #expect(throws: MigrationError.self) {
            try await manager.traditionalMigrateTask(task, newDate: feb10, newPeriod: .day)
        }
    }
}
