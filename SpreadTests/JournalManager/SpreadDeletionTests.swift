import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.UUID
import Testing
@testable import Spread

@Suite(.serialized)
struct SpreadDeletionTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Basic Spread Deletion Tests

    /// Conditions: A day spread is deleted and a parent month spread exists.
    /// Expected: Tasks are reassigned to the month spread.
    @Test @MainActor func testDeleteSpreadReassignsTasksToParent() async throws {
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
                TaskAssignment(period: .day, date: taskDate, status: .open)
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

        try await manager.deleteSpread(daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        // Task should have a new assignment on month spread
        let monthAssignment = updatedTask?.assignments.first { $0.period == .month }
        #expect(monthAssignment != nil)
        #expect(monthAssignment?.status == .open)
    }

    /// Conditions: A day spread is deleted and a parent month spread exists.
    /// Expected: Notes are reassigned to the month spread.
    @Test @MainActor func testDeleteSpreadReassignsNotesToParent() async throws {
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
                NoteAssignment(period: .day, date: noteDate, status: .active)
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

        try await manager.deleteSpread(daySpread)

        let updatedNote = manager.notes.first { $0.id == note.id }

        // Note should have a new assignment on month spread
        let monthAssignment = updatedNote?.assignments.first { $0.period == Period.month }
        #expect(monthAssignment != nil)
        #expect(monthAssignment?.status == .active)
    }

    /// Conditions: A day spread is deleted and no parent spread exists.
    /// Expected: Tasks go to Inbox (no assignment on any spread).
    @Test @MainActor func testDeleteSpreadSendsTasksToInboxWhenNoParent() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        // Initially not in inbox
        #expect(manager.inboxEntries.isEmpty)

        try await manager.deleteSpread(daySpread)

        // Task should be in inbox now
        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == task.id)
    }

    // MARK: - History Preservation Tests

    /// Conditions: A spread is deleted.
    /// Expected: The original assignment is preserved (history maintained).
    @Test @MainActor func testDeleteSpreadPreservesAssignmentHistory() async throws {
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
                TaskAssignment(period: .day, date: taskDate, status: .open)
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

        try await manager.deleteSpread(daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        // Both assignments should exist (original day + new month)
        #expect(updatedTask?.assignments.count == 2)

        // Original day assignment should be marked as migrated
        let dayAssignment = updatedTask?.assignments.first { $0.period == .day }
        #expect(dayAssignment?.status == .migrated)
    }

    // MARK: - Entry Preservation Tests

    /// Conditions: A spread is deleted that has completed tasks.
    /// Expected: Completed tasks are reassigned, not deleted.
    @Test @MainActor func testDeleteSpreadReassignsCompletedTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

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
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.deleteSpread(daySpread)

        // Task should still exist
        #expect(manager.tasks.count == 1)

        let updatedTask = manager.tasks.first { $0.id == completedTask.id }

        // Should have assignment on month spread with complete status
        let monthAssignment = updatedTask?.assignments.first { $0.period == .month }
        #expect(monthAssignment != nil)
        #expect(monthAssignment?.status == .complete)
    }

    /// Conditions: A spread is deleted.
    /// Expected: Entries are never deleted, only reassigned.
    @Test @MainActor func testDeleteSpreadNeverDeletesEntries() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .open)
            ]
        )
        let note = DataModel.Note(
            title: "Test Note",
            date: taskDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .day, date: taskDate, status: .active)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let noteRepo = InMemoryNoteRepository(notes: [note])
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            noteRepository: noteRepo
        )

        try await manager.deleteSpread(daySpread)

        // All entries should still exist
        #expect(manager.tasks.count == 1)
        #expect(manager.notes.count == 1)
    }

    // MARK: - Spread Removal Tests

    /// Conditions: A spread is deleted.
    /// Expected: The spread is removed from the spreads list.
    @Test @MainActor func testDeleteSpreadRemovesSpreadFromList() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            spreadRepository: spreadRepo
        )

        #expect(manager.spreads.count == 1)

        try await manager.deleteSpread(daySpread)

        #expect(manager.spreads.isEmpty)
    }

    /// Conditions: A spread is deleted.
    /// Expected: The spread is removed from the repository.
    @Test @MainActor func testDeleteSpreadPersistsDeletion() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            spreadRepository: spreadRepo
        )

        try await manager.deleteSpread(daySpread)

        let savedSpreads = await spreadRepo.getSpreads()
        #expect(savedSpreads.isEmpty)
    }

    /// Conditions: A spread is deleted.
    /// Expected: Data version increments.
    @Test @MainActor func testDeleteSpreadIncrementsDataVersion() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            spreadRepository: spreadRepo
        )

        let initialVersion = manager.dataVersion

        try await manager.deleteSpread(daySpread)

        #expect(manager.dataVersion > initialVersion)
    }

    // MARK: - Parent Spread Selection Tests

    /// Conditions: A day spread is deleted, month and year spreads exist.
    /// Expected: Tasks are reassigned to month spread (immediate parent).
    @Test @MainActor func testDeleteSpreadReassignsToImmediateParent() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Test Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .open)
            ]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.deleteSpread(daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        // Should be assigned to month (immediate parent), not year
        let monthAssignment = updatedTask?.assignments.first { $0.period == .month }
        let yearAssignment = updatedTask?.assignments.first { $0.period == .year }

        #expect(monthAssignment != nil)
        #expect(yearAssignment == nil)
    }

    /// Conditions: A month spread is deleted, only year spread exists.
    /// Expected: Tasks are reassigned to year spread.
    @Test @MainActor func testDeleteSpreadReassignsToGrandparentWhenNoParent() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)

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
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.deleteSpread(monthSpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }

        // Should be assigned to year spread
        let yearAssignment = updatedTask?.assignments.first { $0.period == .year }
        #expect(yearAssignment != nil)
        #expect(yearAssignment?.status == .open)
    }

    // MARK: - Multiple Entries Tests

    /// Conditions: A spread is deleted with multiple tasks.
    /// Expected: All tasks are reassigned.
    @Test @MainActor func testDeleteSpreadReassignsMultipleTasks() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let task1 = DataModel.Task(
            title: "Task 1",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: taskDate, status: .open)]
        )
        let task2 = DataModel.Task(
            title: "Task 2",
            date: taskDate,
            period: .day,
            status: .complete,
            assignments: [TaskAssignment(period: .day, date: taskDate, status: .complete)]
        )

        let taskRepo = InMemoryTaskRepository(tasks: [task1, task2])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread, daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        try await manager.deleteSpread(daySpread)

        for task in manager.tasks {
            let monthAssignment = task.assignments.first { $0.period == .month }
            #expect(monthAssignment != nil)
        }
    }

    // MARK: - Migrated Entries Tests

    /// Conditions: A spread is deleted that has entries with migrated status.
    /// Expected: Migrated entries are also reassigned (not lost).
    @Test @MainActor func testDeleteSpreadReassignsMigratedEntries() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)

        let migratedTask = DataModel.Task(
            title: "Migrated Task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: taskDate, status: .migrated)
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

        try await manager.deleteSpread(daySpread)

        let updatedTask = manager.tasks.first { $0.id == migratedTask.id }

        // Should have assignment on month spread
        let monthAssignment = updatedTask?.assignments.first { $0.period == .month }
        #expect(monthAssignment != nil)
    }

    // MARK: - Events Handling Tests

    /// Conditions: A spread is deleted and events exist that overlap the spread's date.
    /// Expected: Events are not affected (they have no assignments).
    @Test @MainActor func testDeleteSpreadDoesNotAffectEvents() async throws {
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

        try await manager.deleteSpread(daySpread)

        // Event should still exist and be unchanged
        #expect(manager.events.count == 1)
        #expect(manager.events.first?.id == event.id)
    }

    // MARK: - Data Model Update Tests

    /// Conditions: A spread is deleted.
    /// Expected: Data model is rebuilt without the deleted spread.
    @Test @MainActor func testDeleteSpreadRebuildDataModel() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate

        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)
        let spreadRepo = InMemorySpreadRepository(spreads: [daySpread])

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: taskDate,
            spreadRepository: spreadRepo
        )

        // Data model should contain the day spread
        #expect(manager.dataModel[.day] != nil)

        try await manager.deleteSpread(daySpread)

        // Data model should no longer contain the day spread
        #expect(manager.dataModel[.day] == nil || manager.dataModel[.day]?.isEmpty == true)
    }
}
