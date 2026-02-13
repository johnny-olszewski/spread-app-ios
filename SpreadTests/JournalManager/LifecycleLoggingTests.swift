import Foundation
import Testing
@testable import Spread

/// Tests verifying that lifecycle log points are reached for key operations.
///
/// OSLog output cannot be captured in unit tests, so these tests verify that
/// the code paths containing log statements execute successfully. Each test
/// exercises a specific lifecycle event and confirms the expected side effects,
/// which validates the log statement is reached.
@MainActor
struct LifecycleLoggingTests {

    // MARK: - Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        testCalendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
    }

    private func makeManager(
        tasks: [DataModel.Task] = [],
        spreads: [DataModel.Spread] = [],
        notes: [DataModel.Note] = []
    ) async throws -> JournalManager {
        let taskRepo = InMemoryTaskRepository(tasks: tasks)
        let spreadRepo = InMemorySpreadRepository(spreads: spreads)
        let noteRepo = InMemoryNoteRepository(notes: notes)
        return try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            noteRepository: noteRepo
        )
    }

    // MARK: - Assignment Created

    /// Conditions: A task is added when a matching spread exists.
    /// Expected: Task is assigned to the spread (log point: "Assignment created: task").
    @Test func assignmentCreatedLogPointReachedOnAddTask() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let manager = try await makeManager(spreads: [daySpread])

        let task = try await manager.addTask(title: "Test", date: today, period: .day)

        #expect(task.assignments.count == 1)
    }

    /// Conditions: A new spread is created that captures an inbox entry.
    /// Expected: Inbox entry is auto-assigned (log points: "Assignment created" + "Inbox resolved").
    @Test func assignmentCreatedLogPointReachedOnInboxResolution() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let task = DataModel.Task(
            title: "Inbox task",
            date: today,
            period: .day,
            status: .open,
            assignments: []
        )
        let manager = try await makeManager(tasks: [task])

        // Task starts in inbox
        #expect(manager.inboxEntries.count == 1)

        // Adding a matching spread resolves the inbox entry
        _ = try await manager.addSpread(period: .day, date: today)

        #expect(manager.inboxEntries.isEmpty)
        let updatedTask = manager.tasks.first { $0.id == task.id }
        #expect(updatedTask?.assignments.count == 1)
    }

    // MARK: - Migration Performed

    /// Conditions: A task is migrated from a month spread to a day spread.
    /// Expected: Migration completes (log point: "Migration performed: task").
    @Test func migrationLogPointReachedOnTaskMigration() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)

        let task = DataModel.Task(
            title: "Migrate me",
            date: today,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: monthDate, status: .open)]
        )
        let manager = try await makeManager(tasks: [task], spreads: [monthSpread, daySpread])

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }
        #expect(updatedTask?.assignments.count == 2)
    }

    /// Conditions: A note is migrated from a month spread to a day spread.
    /// Expected: Migration completes (log point: "Migration performed: note").
    @Test func migrationLogPointReachedOnNoteMigration() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)

        let note = DataModel.Note(
            title: "Migrate note",
            date: today,
            period: .day,
            status: .active,
            assignments: [NoteAssignment(period: .month, date: monthDate, status: .active)]
        )
        let manager = try await makeManager(
            spreads: [monthSpread, daySpread],
            notes: [note]
        )

        try await manager.migrateNote(note, from: monthSpread, to: daySpread)

        let updatedNote = manager.notes.first { $0.id == note.id }
        #expect(updatedNote?.assignments.count == 2)
    }

    /// Conditions: Multiple tasks are batch-migrated.
    /// Expected: Batch migration completes (log point: "Batch migration performed").
    @Test func migrationLogPointReachedOnBatchMigration() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)

        let tasks = (1...3).map { i in
            DataModel.Task(
                title: "Batch \(i)",
                date: today,
                period: .day,
                status: .open,
                assignments: [TaskAssignment(period: .month, date: monthDate, status: .open)]
            )
        }
        let manager = try await makeManager(tasks: tasks, spreads: [monthSpread, daySpread])

        try await manager.migrateTasksBatch(tasks, from: monthSpread, to: daySpread)

        for task in manager.tasks {
            #expect(task.assignments.count == 2)
        }
    }

    // MARK: - Spread Deleted

    /// Conditions: A day spread with an assigned task is deleted.
    /// Expected: Spread is deleted and task reassigned (log point: "Spread deleted").
    @Test func spreadDeletedLogPointReachedOnDeletion() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        let task = DataModel.Task(
            title: "On day spread",
            date: today,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )
        let manager = try await makeManager(tasks: [task], spreads: [monthSpread, daySpread])

        try await manager.deleteSpread(daySpread)

        #expect(manager.spreads.count == 1)
        #expect(manager.spreads.first?.period == .month)
    }

    // MARK: - Task Created (debug log)

    /// Conditions: A task is created with no matching spread.
    /// Expected: Task goes to inbox (log point: "Task created ... → Inbox").
    @Test func taskCreatedLogPointReachedForInbox() async throws {
        let today = Self.testDate
        let manager = try await makeManager()

        let task = try await manager.addTask(title: "No spread", date: today, period: .day)

        #expect(task.assignments.isEmpty)
    }

    /// Conditions: A task is created with a matching spread.
    /// Expected: Task is assigned (log point: "Task created ... → day spread").
    @Test func taskCreatedLogPointReachedForAssignment() async throws {
        let calendar = Self.testCalendar
        let today = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let manager = try await makeManager(spreads: [daySpread])

        let task = try await manager.addTask(title: "Has spread", date: today, period: .day)

        #expect(!task.assignments.isEmpty)
    }
}
