import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct MigrationTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Task Migration Tests

    /// Conditions: A task has an assignment on a month spread and is migrated to a day spread.
    /// Expected: Source assignment status becomes migrated, destination assignment status is open.
    @Test @MainActor func testMigrateTaskUpdatesSourceAssignmentToMigrated() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        // Create spreads
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Create task with assignment to month spread
        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }
        let sourceAssignment = updatedTask?.assignments.first { $0.period == .month }

        #expect(sourceAssignment?.status == .migrated)
    }

    /// Conditions: A task is migrated from a month spread to a day spread.
    /// Expected: A new assignment is created on the destination spread with open status.
    @Test @MainActor func testMigrateTaskCreatesDestinationAssignment() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }
        let destinationAssignment = updatedTask?.assignments.first { $0.period == .day }

        #expect(destinationAssignment != nil)
        #expect(destinationAssignment?.status == .open)
    }

    /// Conditions: A task is migrated from one spread to another.
    /// Expected: Task now has two assignments (source migrated, destination open).
    @Test @MainActor func testMigrateTaskPreservesAssignmentHistory() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        #expect(updatedTask?.assignments.count == 2)
    }

    /// Conditions: A task is migrated.
    /// Expected: Changes are persisted to the repository.
    @Test @MainActor func testMigrateTaskPersistsChanges() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let savedTasks = await taskRepo.getTasks()
        let savedTask = savedTasks.first { $0.id == task.id }

        #expect(savedTask?.assignments.count == 2)
    }

    /// Conditions: A task with migrated status is migrated to a new spread.
    /// Expected: Task top-level status is set to open.
    @Test @MainActor func testMigrateTaskUpdatesTopLevelStatusToOpen() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .migrated,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        #expect(updatedTask?.status == .open)
    }

    /// Conditions: A task is migrated.
    /// Expected: Data version increments.
    @Test @MainActor func testMigrateTaskIncrementsDataVersion() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let initialVersion = manager.dataVersion

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        #expect(manager.dataVersion > initialVersion)
    }

    /// Conditions: A task is migrated to a spread where it already has an assignment.
    /// Expected: Existing destination assignment status is updated, no duplicate created.
    @Test @MainActor func testMigrateTaskUpdatesExistingDestinationAssignment() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Task already has assignment on destination but with migrated status
        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open),
                TaskAssignment(period: .day, date: taskDate, status: .migrated)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTask(task, from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        // Should still be 2 assignments (no duplicate)
        #expect(updatedTask?.assignments.count == 2)

        // Destination assignment should be open now
        let destinationAssignment = updatedTask?.assignments.first { $0.period == .day }
        #expect(destinationAssignment?.status == .open)
    }

    /// Conditions: Attempt to migrate a cancelled task.
    /// Expected: Migration is rejected with an error.
    @Test @MainActor func testMigrateTaskRejectsCancelledTask() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .cancelled)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        await #expect(throws: MigrationError.self) {
            try await manager.migrateTask(cancelledTask, from: monthSpread, to: daySpread)
        }
    }

    /// Conditions: Attempt to migrate a task that has no assignment on the source spread.
    /// Expected: Migration is rejected with an error.
    @Test @MainActor func testMigrateTaskRejectsTaskWithoutSourceAssignment() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        // Task has no assignment on month spread
        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: []
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        await #expect(throws: MigrationError.self) {
            try await manager.migrateTask(task, from: monthSpread, to: daySpread)
        }
    }

    /// Conditions: Attempt to migrate a task to a multiday spread.
    /// Expected: Migration is rejected with an error.
    @Test @MainActor func testMigrateTaskRejectsMigrationToMultidaySpread() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, multidaySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        await #expect(throws: MigrationError.self) {
            try await manager.migrateTask(task, from: monthSpread, to: multidaySpread)
        }
    }

    // MARK: - Note Migration Tests

    /// Conditions: A note has an assignment on a month spread and is migrated to a day spread.
    /// Expected: Source assignment status becomes migrated, destination assignment status is active.
    @Test @MainActor func testMigrateNoteUpdatesSourceAssignmentToMigrated() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: calendar)

        let note = DataModel.Note(
            title: "Test Note",
            date: noteDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .month, date: noteDate, status: .active)
            ]
        )

        let noteRepo = InMemoryNoteRepository(notes: [note])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: noteDate,
            spreadRepository: spreadRepo,
            noteRepository: noteRepo
        )

        try await manager.migrateNote(note, from: monthSpread, to: daySpread)

        let updatedNote = manager.notes.first { $0.id == note.id }
        let sourceAssignment = updatedNote?.assignments.first { $0.period == Period.month }

        #expect(sourceAssignment?.status == .migrated)
    }

    /// Conditions: A note is migrated from a month spread to a day spread.
    /// Expected: A new assignment is created on the destination spread with active status.
    @Test @MainActor func testMigrateNoteCreatesDestinationAssignment() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: calendar)

        let note = DataModel.Note(
            title: "Test Note",
            date: noteDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .month, date: noteDate, status: .active)
            ]
        )

        let noteRepo = InMemoryNoteRepository(notes: [note])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: noteDate,
            spreadRepository: spreadRepo,
            noteRepository: noteRepo
        )

        try await manager.migrateNote(note, from: monthSpread, to: daySpread)

        let updatedNote = manager.notes.first { $0.id == note.id }
        let destinationAssignment = updatedNote?.assignments.first { $0.period == Period.day }

        #expect(destinationAssignment != nil)
        #expect(destinationAssignment?.status == .active)
    }

    /// Conditions: A note is migrated.
    /// Expected: Note now has two assignments (source migrated, destination active).
    @Test @MainActor func testMigrateNotePreservesAssignmentHistory() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: calendar)

        let note = DataModel.Note(
            title: "Test Note",
            date: noteDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .month, date: noteDate, status: .active)
            ]
        )

        let noteRepo = InMemoryNoteRepository(notes: [note])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: noteDate,
            spreadRepository: spreadRepo,
            noteRepository: noteRepo
        )

        try await manager.migrateNote(note, from: monthSpread, to: daySpread)

        let updatedNote = manager.notes.first { $0.id == note.id }

        #expect(updatedNote?.assignments.count == 2)
    }

    /// Conditions: A note is migrated.
    /// Expected: Changes are persisted to the repository.
    @Test @MainActor func testMigrateNotePersistsChanges() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: calendar)

        let note = DataModel.Note(
            title: "Test Note",
            date: noteDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .month, date: noteDate, status: .active)
            ]
        )

        let noteRepo = InMemoryNoteRepository(notes: [note])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: noteDate,
            spreadRepository: spreadRepo,
            noteRepository: noteRepo
        )

        try await manager.migrateNote(note, from: monthSpread, to: daySpread)

        let savedNotes = await noteRepo.getNotes()
        let savedNote = savedNotes.first { $0.id == note.id }

        #expect(savedNote?.assignments.count == 2)
    }

    // MARK: - Batch Task Migration Tests

    /// Conditions: Multiple tasks are migrated in a batch from month to day spread.
    /// Expected: All tasks have new assignments on the destination spread.
    @Test @MainActor func testMigrateTasksBatchMigratesAllTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task1 = DataModel.Task(
            title: "Task 1",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: taskDate, status: .open)]
        )
        let task2 = DataModel.Task(
            title: "Task 2",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: taskDate, status: .open)]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task1, task2])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTasksBatch([task1, task2], from: monthSpread, to: daySpread)

        for task in manager.tasks {
            #expect(task.assignments.count == 2)
            let destinationAssignment = task.assignments.first { $0.period == .day }
            #expect(destinationAssignment?.status == .open)
        }
    }

    /// Conditions: Batch migration includes a task with migrated status.
    /// Expected: Task top-level status is set to open.
    @Test @MainActor func testMigrateTasksBatchUpdatesTopLevelStatus() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let migratedTask = DataModel.Task(
            title: "Migrated Task",
            date: taskDate,
            period: .day,
            status: .migrated,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [migratedTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTasksBatch([migratedTask], from: monthSpread, to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == migratedTask.id }

        #expect(updatedTask?.status == .open)
    }

    /// Conditions: Batch migration is attempted with an empty task array.
    /// Expected: No error is thrown, no changes made.
    @Test @MainActor func testMigrateTasksBatchHandlesEmptyArray() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            spreadRepository: spreadRepo
        )

        let initialVersion = manager.dataVersion

        try await manager.migrateTasksBatch([], from: monthSpread, to: daySpread)

        // No data version change for empty batch
        #expect(manager.dataVersion == initialVersion)
    }

    /// Conditions: Batch migration skips cancelled tasks in the batch.
    /// Expected: Only non-cancelled tasks are migrated.
    @Test @MainActor func testMigrateTasksBatchSkipsCancelledTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let openTask = DataModel.Task(
            title: "Open Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: taskDate, status: .open)]
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: [TaskAssignment(period: .month, date: taskDate, status: .cancelled)]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [openTask, cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.migrateTasksBatch([openTask, cancelledTask], from: monthSpread, to: daySpread)

        let updatedOpenTask = manager.tasks.first { $0.id == openTask.id }
        let updatedCancelledTask = manager.tasks.first { $0.id == cancelledTask.id }

        // Open task should be migrated
        #expect(updatedOpenTask?.assignments.count == 2)

        // Cancelled task should NOT be migrated
        #expect(updatedCancelledTask?.assignments.count == 1)
    }

    // MARK: - Event Migration Blocked Tests

    /// Conditions: Attempt to migrate an event.
    /// Expected: Migration is blocked with an error.
    @Test @MainActor func testEventMigrationIsBlocked() async throws {
        let calendar = Self.testCalendar
        let eventDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: eventDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: eventDate, calendar: calendar)

        let event = DataModel.Event(
            title: "Test Event",
            startDate: eventDate,
            endDate: eventDate
        )

        let eventRepo = InMemoryEventRepository(events: [event])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: eventDate,
            spreadRepository: spreadRepo,
            eventRepository: eventRepo
        )

        await #expect(throws: MigrationError.self) {
            try await manager.migrateEvent(event, from: monthSpread, to: daySpread)
        }
    }

    // MARK: - Eligible Tasks for Migration Tests

    /// Conditions: Two tasks exist on a year spread: one open, one cancelled.
    /// Expected: Only the open task is eligible for migration.
    @Test @MainActor func testEligibleTasksForMigrationExcludesCancelled() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)

        let openTask = DataModel.Task(
            title: "Open Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .cancelled)]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [openTask, cancelledTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let eligible = manager.eligibleTasksForMigration(from: yearSpread, to: monthSpread)

        #expect(eligible.count == 1)
        #expect(eligible.first?.id == openTask.id)
    }

    /// Conditions: Tasks exist on a year spread: one already has assignment on destination.
    /// Expected: Task with existing destination assignment is still eligible (will update status).
    @Test @MainActor func testEligibleTasksIncludesTasksWithExistingDestinationAssignment() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)

        let taskWithExistingAssignment = DataModel.Task(
            title: "Task with Both",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .year, date: taskDate, status: .open),
                TaskAssignment(period: .month, date: taskDate, status: .migrated)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [taskWithExistingAssignment])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let eligible = manager.eligibleTasksForMigration(from: yearSpread, to: monthSpread)

        #expect(eligible.count == 1)
    }

    /// Conditions: A task exists on a year spread with a completed assignment.
    /// Expected: Completed task is not eligible for migration.
    @Test @MainActor func testEligibleTasksExcludesCompletedOnSource() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)

        let completedTask = DataModel.Task(
            title: "Completed Task",
            date: taskDate,
            period: .day,
            status: .complete,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .complete)]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [completedTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let eligible = manager.eligibleTasksForMigration(from: yearSpread, to: monthSpread)

        #expect(eligible.isEmpty)
    }

    /// Conditions: A task exists with migrated status on source spread.
    /// Expected: Already-migrated task is not eligible for migration.
    @Test @MainActor func testEligibleTasksExcludesAlreadyMigratedOnSource() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)

        let migratedTask = DataModel.Task(
            title: "Migrated Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .migrated)]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [migratedTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let eligible = manager.eligibleTasksForMigration(from: yearSpread, to: monthSpread)

        #expect(eligible.isEmpty)
    }
}
