import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.UUID
import Testing
@testable import Spread

@Suite(.serialized)
struct InboxTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Inbox Population Tests

    @Test @MainActor func testInboxIncludesTaskWithNoAssignments() async throws {
        let task = DataModel.Task(
            title: "Unassigned Task",
            date: Self.testDate,
            period: .day,
            assignments: []
        )
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == task.id)
    }

    @Test @MainActor func testInboxIncludesNoteWithNoAssignments() async throws {
        let note = DataModel.Note(
            title: "Unassigned Note",
            date: Self.testDate,
            period: .day,
            assignments: []
        )
        let noteRepo = InMemoryNoteRepository(notes: [note])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            noteRepository: noteRepo
        )

        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == note.id)
    }

    @Test @MainActor func testInboxIncludesTaskWithNoMatchingSpread() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Task for January 15",
            date: taskDate,
            period: .day,
            assignments: [
                TaskAssignment(
                    period: .day,
                    date: taskDate,
                    status: .open
                )
            ]
        )
        // Create a spread for a different date (January 20)
        let differentDate = calendar.date(from: .init(year: 2026, month: 1, day: 20))!
        let spread = DataModel.Spread(period: .day, date: differentDate, calendar: calendar)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == task.id)
    }

    @Test @MainActor func testInboxExcludesTaskWithMatchingSpread() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Task with Spread",
            date: taskDate,
            period: .day,
            assignments: [
                TaskAssignment(
                    period: .day,
                    date: taskDate,
                    status: .open
                )
            ]
        )
        let spread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    @Test @MainActor func testInboxExcludesTaskWhenParentSpreadExists() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Day Task",
            date: taskDate,
            period: .day,
            assignments: []
        )
        // Create month spread (parent of day)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let spreadRepo = InMemorySpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        // Task should not be in inbox because a parent spread exists
        #expect(manager.inboxEntries.isEmpty)
    }

    // MARK: - Events Excluded Tests

    @Test @MainActor func testInboxExcludesEvents() async throws {
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )
        let eventRepo = InMemoryEventRepository(events: [event])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            eventRepository: eventRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    @Test @MainActor func testInboxExcludesEventsEvenWithoutMatchingSpreads() async throws {
        let event = DataModel.Event(
            title: "Orphan Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )
        let eventRepo = InMemoryEventRepository(events: [event])
        // No spreads

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            eventRepository: eventRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    // MARK: - Cancelled Tasks Excluded Tests

    @Test @MainActor func testInboxExcludesCancelledTasks() async throws {
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: Self.testDate,
            period: .day,
            status: .cancelled,
            assignments: []
        )
        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    @Test @MainActor func testInboxExcludesCancelledTasksEvenWithAssignments() async throws {
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task with Assignments",
            date: Self.testDate,
            period: .day,
            status: .cancelled,
            assignments: [
                TaskAssignment(
                    period: .day,
                    date: Self.testDate,
                    status: .cancelled
                )
            ]
        )
        let taskRepo = InMemoryTaskRepository(tasks: [cancelledTask])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    // MARK: - Inbox Count Tests

    @Test @MainActor func testInboxCountReturnsZeroWhenEmpty() async throws {
        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate
        )

        #expect(manager.inboxCount == 0)
    }

    @Test @MainActor func testInboxCountReturnsCorrectCount() async throws {
        let task1 = DataModel.Task(title: "Task 1", date: Self.testDate, assignments: [])
        let task2 = DataModel.Task(title: "Task 2", date: Self.testDate, assignments: [])
        let note = DataModel.Note(title: "Note 1", date: Self.testDate, assignments: [])
        let taskRepo = InMemoryTaskRepository(tasks: [task1, task2])
        let noteRepo = InMemoryNoteRepository(notes: [note])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            noteRepository: noteRepo
        )

        #expect(manager.inboxCount == 3)
    }

    // MARK: - Auto-Resolve Tests

    @Test @MainActor func testAddSpreadAutoResolvesInboxTask() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Inbox Task",
            date: taskDate,
            period: .day,
            assignments: []
        )
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        // Task should be in inbox initially
        #expect(manager.inboxEntries.count == 1)

        // Add a spread matching the task's date
        try await manager.addSpread(period: .day, date: taskDate)

        // Task should be auto-resolved (no longer in inbox)
        #expect(manager.inboxEntries.isEmpty)
    }

    @Test @MainActor func testAddSpreadAutoResolvesInboxNote() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate
        let note = DataModel.Note(
            title: "Inbox Note",
            date: noteDate,
            period: .day,
            assignments: []
        )
        let noteRepo = InMemoryNoteRepository(notes: [note])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            noteRepository: noteRepo
        )

        // Note should be in inbox initially
        #expect(manager.inboxEntries.count == 1)

        // Add a spread matching the note's date
        try await manager.addSpread(period: .day, date: noteDate)

        // Note should be auto-resolved (no longer in inbox)
        #expect(manager.inboxEntries.isEmpty)
    }

    @Test @MainActor func testAddSpreadAutoResolvesMultipleInboxEntries() async throws {
        let calendar = Self.testCalendar
        let date = Self.testDate
        let task1 = DataModel.Task(title: "Task 1", date: date, period: .day, assignments: [])
        let task2 = DataModel.Task(title: "Task 2", date: date, period: .day, assignments: [])
        let note = DataModel.Note(title: "Note 1", date: date, period: .day, assignments: [])
        let taskRepo = InMemoryTaskRepository(tasks: [task1, task2])
        let noteRepo = InMemoryNoteRepository(notes: [note])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            noteRepository: noteRepo
        )

        #expect(manager.inboxEntries.count == 3)

        try await manager.addSpread(period: .day, date: date)

        #expect(manager.inboxEntries.isEmpty)
    }

    @Test @MainActor func testAddSpreadCreatesAssignmentsForResolvedEntries() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Inbox Task",
            date: taskDate,
            period: .day,
            assignments: []
        )
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        try await manager.addSpread(period: .day, date: taskDate)

        // Check the task has an assignment now
        let updatedTask = manager.tasks.first { $0.id == task.id }
        #expect(updatedTask?.assignments.count == 1)
        #expect(updatedTask?.assignments.first?.period == .day)
        #expect(updatedTask?.assignments.first?.status == .open)
    }

    @Test @MainActor func testAddSpreadAutoResolvesFromParentPeriod() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Day Task",
            date: taskDate,
            period: .day,
            assignments: []
        )
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        // Task in inbox
        #expect(manager.inboxEntries.count == 1)

        // Add a month spread (parent of day)
        try await manager.addSpread(period: .month, date: taskDate)

        // Task should be auto-resolved to month spread
        #expect(manager.inboxEntries.isEmpty)

        let updatedTask = manager.tasks.first { $0.id == task.id }
        #expect(updatedTask?.assignments.count == 1)
        #expect(updatedTask?.assignments.first?.period == .month)
    }

    @Test @MainActor func testAddSpreadIncrementsDataVersion() async throws {
        let calendar = Self.testCalendar

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate
        )

        let initialVersion = manager.dataVersion

        try await manager.addSpread(period: .day, date: Self.testDate)

        #expect(manager.dataVersion > initialVersion)
    }

    @Test @MainActor func testAddSpreadPersistsSpreadToRepository() async throws {
        let calendar = Self.testCalendar
        let spreadRepo = InMemorySpreadRepository()

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            spreadRepository: spreadRepo
        )

        try await manager.addSpread(period: .day, date: Self.testDate)

        let savedSpreads = await spreadRepo.getSpreads()
        #expect(savedSpreads.count == 1)
        #expect(savedSpreads.first?.period == .day)
    }

    @Test @MainActor func testAddSpreadDoesNotAutoResolveUnmatchedEntries() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let differentDate = calendar.date(from: .init(year: 2026, month: 2, day: 15))!
        let task = DataModel.Task(
            title: "February Task",
            date: differentDate,
            period: .day,
            assignments: []
        )
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        // Task should be in inbox
        #expect(manager.inboxEntries.count == 1)

        // Add a spread for January (different month)
        try await manager.addSpread(period: .day, date: taskDate)

        // Task should still be in inbox (different date)
        #expect(manager.inboxEntries.count == 1)
    }

    // MARK: - Mixed Scenarios

    @Test @MainActor func testInboxContainsMixOfTasksAndNotes() async throws {
        let task = DataModel.Task(title: "Task", date: Self.testDate, assignments: [])
        let note = DataModel.Note(title: "Note", date: Self.testDate, assignments: [])
        let event = DataModel.Event(title: "Event", startDate: Self.testDate, endDate: Self.testDate)
        let taskRepo = InMemoryTaskRepository(tasks: [task])
        let noteRepo = InMemoryNoteRepository(notes: [note])
        let eventRepo = InMemoryEventRepository(events: [event])

        let manager = try await JournalManager.makeForTesting(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            eventRepository: eventRepo,
            noteRepository: noteRepo
        )

        #expect(manager.inboxCount == 2)

        let taskInInbox = manager.inboxEntries.contains { $0.id == task.id }
        let noteInInbox = manager.inboxEntries.contains { $0.id == note.id }
        let eventInInbox = manager.inboxEntries.contains { $0.id == event.id }

        #expect(taskInInbox)
        #expect(noteInInbox)
        #expect(!eventInInbox)
    }
}
