import Foundation
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

    /// Conditions: A task has no assignments and is loaded into the task repository.
    /// Expected: Inbox contains the task.
    @Test @MainActor func testInboxIncludesTaskWithNoAssignments() async throws {
        let task = DataModel.Task(
            title: "Unassigned Task",
            date: Self.testDate,
            period: .day,
            currentAssignments: []
        )
        let taskRepo = TestTaskRepository(tasks: [task])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == task.id)
    }

    /// Conditions: A note has no assignments and is loaded into the note repository.
    /// Expected: Inbox contains the note.
    /// Conditions: An unassigned note with no matching spread.
    /// Expected: the note is excluded from Inbox — `Note.isInboxEligible == false`
    /// (SPRD-247/248: notes never surface as Inbox items, unlike unassigned tasks).
    @Test @MainActor func testInboxExcludesNoteWithNoAssignments() async throws {
        let note = DataModel.Note(
            title: "Unassigned Note",
            date: Self.testDate,
            period: .day,
            currentAssignments: []
        )
        let noteRepo = TestNoteRepository(notes: [note])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            noteRepository: noteRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    /// Conditions: A task has an assignment but no matching spread exists for its date.
    /// Expected: Inbox contains the task.
    @Test @MainActor func testInboxIncludesTaskWithNoMatchingSpread() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Task for January 15",
            date: taskDate,
            period: .day,
            currentAssignments: [
                Assignment(
                    period: .day,
                    date: taskDate,
                    status: .open
                )
            ]
        )
        // Create a spread for a different date (January 20)
        let differentDate = calendar.date(from: .init(year: 2026, month: 1, day: 20))!
        let spread = DataModel.Spread(period: .day, date: differentDate, calendar: calendar)
        let taskRepo = TestTaskRepository(tasks: [task])
        let spreadRepo = TestSpreadRepository(spreads: [spread])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == task.id)
    }

    /// Conditions: A task has an assignment and a matching spread exists for its date.
    /// Expected: Inbox is empty.
    @Test @MainActor func testInboxExcludesTaskWithMatchingSpread() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Task with Spread",
            date: taskDate,
            period: .day,
            currentAssignments: [
                Assignment(
                    period: .day,
                    date: taskDate,
                    status: .open
                )
            ]
        )
        let spread = DataModel.Spread(period: .day, date: taskDate, calendar: calendar)
        let taskRepo = TestTaskRepository(tasks: [task])
        let spreadRepo = TestSpreadRepository(spreads: [spread])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    /// Conditions: A task has no assignments and a parent period spread exists.
    /// Expected: Inbox still contains the task.
    @Test @MainActor func testInboxIncludesTaskWithNoAssignmentsEvenWhenParentSpreadExists() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Day Task",
            date: taskDate,
            period: .day,
            currentAssignments: []
        )
        // Create month spread (parent of day)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let taskRepo = TestTaskRepository(tasks: [task])
        let spreadRepo = TestSpreadRepository(spreads: [monthSpread])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        #expect(manager.inboxEntries.count == 1)
        #expect(manager.inboxEntries.first?.id == task.id)
    }

    // MARK: - Events Excluded Tests

    /// Conditions: An event exists in the event repository.
    /// Expected: Inbox remains empty.
    @Test @MainActor func testInboxExcludesEvents() async throws {
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )
        let eventRepo = TestEventRepository(events: [event])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            eventRepository: eventRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    /// Conditions: An event exists and there are no spreads.
    /// Expected: Inbox remains empty.
    @Test @MainActor func testInboxExcludesEventsEvenWithoutMatchingSpreads() async throws {
        let event = DataModel.Event(
            title: "Orphan Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )
        let eventRepo = TestEventRepository(events: [event])
        // No spreads

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            eventRepository: eventRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    // MARK: - Cancelled Tasks Excluded Tests

    /// Conditions: A task is cancelled and has no assignments.
    /// Expected: Inbox remains empty.
    @Test @MainActor func testInboxExcludesCancelledTasks() async throws {
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task",
            date: Self.testDate,
            period: .day,
            status: .cancelled,
            currentAssignments: []
        )
        let taskRepo = TestTaskRepository(tasks: [cancelledTask])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    /// Conditions: A task is cancelled and has cancelled assignments.
    /// Expected: Inbox remains empty.
    @Test @MainActor func testInboxExcludesCancelledTasksEvenWithAssignments() async throws {
        let cancelledTask = DataModel.Task(
            title: "Cancelled Task with Assignments",
            date: Self.testDate,
            period: .day,
            status: .cancelled,
            currentAssignments: [
                Assignment(
                    period: .day,
                    date: Self.testDate,
                    status: .cancelled
                )
            ]
        )
        let taskRepo = TestTaskRepository(tasks: [cancelledTask])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        #expect(manager.inboxEntries.isEmpty)
    }

    // MARK: - Inbox Count Tests

    /// Conditions: No inbox-eligible entries exist.
    /// Expected: Inbox count is zero.
    @Test @MainActor func testInboxCountReturnsZeroWhenEmpty() async throws {
        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate
        )

        #expect(manager.inboxCount == 0)
    }

    /// Conditions: Two tasks and one note have no assignments.
    /// Expected: Inbox count is two — the note is excluded (`Note.isInboxEligible == false`,
    /// SPRD-247/248), only the two unassigned tasks count.
    @Test @MainActor func testInboxCountReturnsCorrectCount() async throws {
        let task1 = DataModel.Task(title: "Task 1", date: Self.testDate, currentAssignments: [])
        let task2 = DataModel.Task(title: "Task 2", date: Self.testDate, currentAssignments: [])
        let note = DataModel.Note(title: "Note 1", date: Self.testDate, currentAssignments: [])
        let taskRepo = TestTaskRepository(tasks: [task1, task2])
        let noteRepo = TestNoteRepository(notes: [note])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            noteRepository: noteRepo
        )

        #expect(manager.inboxCount == 2)
    }

    // MARK: - Auto-Resolve Tests

    /// Conditions: A task is in the inbox and a matching day spread is added.
    /// Expected: The new spread becomes the task's current assignment and the task leaves Inbox.
    @Test @MainActor func testAddSpreadAutoAssignsMatchingInboxTask() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Inbox Task",
            date: taskDate,
            period: .day,
            currentAssignments: []
        )
        let taskRepo = TestTaskRepository(tasks: [task])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        // Task should be in inbox initially
        #expect(manager.inboxEntries.count == 1)

        // Add a spread matching the task's date
        let spread = try await manager.addSpread(period: .day, date: taskDate)

        #expect(manager.inboxEntries.isEmpty)
        let updatedTask = manager.tasks.first { $0.id == task.id }
        #expect(updatedTask?.allAssignmentsForTesting.count == 1)
        #expect(updatedTask?.allAssignmentsForTesting.first?.status == .open)
        #expect(updatedTask?.allAssignmentsForTesting.first?.matches(period: spread.period, date: spread.date, calendar: calendar) == true)
    }

    /// Conditions: An unassigned note (not counted in Inbox — `Note.isInboxEligible ==
    /// false`, SPRD-247/248) and a matching day spread is added.
    /// Expected: The new spread becomes the note's current assignment via the auto-migration
    /// reconciliation pass, independent of Inbox membership.
    @Test @MainActor func testAddSpreadAutoAssignsMatchingInboxNote() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate
        let note = DataModel.Note(
            title: "Inbox Note",
            date: noteDate,
            period: .day,
            currentAssignments: []
        )
        let noteRepo = TestNoteRepository(notes: [note])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            noteRepository: noteRepo
        )

        // The note is unassigned but not counted in Inbox (notes are never Inbox-eligible).
        #expect(manager.inboxEntries.isEmpty)

        // Add a spread matching the note's date
        let spread = try await manager.addSpread(period: .day, date: noteDate)

        #expect(manager.inboxEntries.isEmpty)
        let updatedNote = manager.notes.first { $0.id == note.id }
        #expect(updatedNote?.allAssignmentsForTesting.count == 1)
        #expect(updatedNote?.allAssignmentsForTesting.first?.status == .active)
        #expect(updatedNote?.allAssignmentsForTesting.first?.matches(period: spread.period, date: spread.date, calendar: calendar) == true)
    }

    /// Conditions: Two tasks and one note are in the inbox and a matching day spread is added.
    /// Expected: All matching entries resolve onto the new spread and Inbox becomes empty.
    @Test @MainActor func testAddSpreadAutoAssignsMultipleMatchingInboxEntries() async throws {
        let calendar = Self.testCalendar
        let date = Self.testDate
        let task1 = DataModel.Task(title: "Task 1", date: date, period: .day, currentAssignments: [])
        let task2 = DataModel.Task(title: "Task 2", date: date, period: .day, currentAssignments: [])
        let note = DataModel.Note(title: "Note 1", date: date, period: .day, currentAssignments: [])
        let taskRepo = TestTaskRepository(tasks: [task1, task2])
        let noteRepo = TestNoteRepository(notes: [note])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            noteRepository: noteRepo
        )

        // Only the two tasks count toward Inbox — the note is never Inbox-eligible
        // (`Note.isInboxEligible == false`, SPRD-247/248).
        #expect(manager.inboxEntries.count == 2)

        let spread = try await manager.addSpread(period: .day, date: date)

        #expect(manager.inboxEntries.isEmpty)
        for task in manager.tasks {
            #expect(task.allAssignmentsForTesting.count == 1)
            #expect(task.allAssignmentsForTesting.first?.matches(period: spread.period, date: spread.date, calendar: calendar) == true)
        }
        for note in manager.notes {
            #expect(note.allAssignmentsForTesting.count == 1)
            #expect(note.allAssignmentsForTesting.first?.matches(period: spread.period, date: spread.date, calendar: calendar) == true)
        }
    }

    /// Conditions: A task is in the inbox and a matching day spread is added.
    /// Expected: The task auto-assigns to the new spread, so no Inbox migration candidate remains.
    @Test @MainActor func testAddSpreadResolvesInboxTaskInsteadOfLeavingMigrationCandidate() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Inbox Task",
            date: taskDate,
            period: .day,
            currentAssignments: []
        )
        let taskRepo = TestTaskRepository(tasks: [task])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        let spread = try await manager.addSpread(period: .day, date: taskDate)

        #expect(manager.inboxEntries.isEmpty)
        let candidates = manager.migrationCandidates(to: spread)
        #expect(candidates.isEmpty)
    }

    /// Conditions: A day task is in the inbox and a parent month spread is added.
    /// Expected: The task auto-assigns to the new month spread and leaves Inbox.
    @Test @MainActor func testAddSpreadAutoAssignsInboxTaskToBestAvailableParentPeriod() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let task = DataModel.Task(
            title: "Day Task",
            date: taskDate,
            period: .day,
            currentAssignments: []
        )
        let taskRepo = TestTaskRepository(tasks: [task])

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: taskRepo
        )

        // Task in inbox
        #expect(manager.inboxEntries.count == 1)

        let spread = try await manager.addSpread(period: .month, date: taskDate)

        #expect(manager.inboxEntries.isEmpty)
        let updatedTask = try #require(manager.tasks.first { $0.id == task.id })
        #expect(updatedTask.allAssignmentsForTesting.count == 1)
        #expect(updatedTask.allAssignmentsForTesting.first?.matches(period: spread.period, date: spread.date, calendar: calendar) == true)
        let candidates = manager.migrationCandidates(to: spread)
        #expect(candidates.isEmpty)
    }

    /// Conditions: A day task is currently assigned to a year spread and a matching month spread is added.
    /// Expected: The task auto-migrates to the new month spread and leaves the year spread's current content.
    @Test @MainActor func testAddMonthSpreadAutoMigratesYearAssignedTaskToMonth() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: calendar)
        let task = DataModel.Task(
            title: "Year Assigned Task",
            date: taskDate,
            period: .day,
            currentAssignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: TestTaskRepository(tasks: [task]),
            spreadRepository: TestSpreadRepository(spreads: [yearSpread])
        )

        let monthSpread = try await manager.addSpread(period: .month, date: taskDate)

        let updatedTask = try #require(manager.tasks.first { $0.id == task.id })
        #expect(updatedTask.allAssignmentsForTesting.count == 2)
        #expect(updatedTask.allAssignmentsForTesting.first?.status == .migrated)
        #expect(updatedTask.allAssignmentsForTesting.last?.matches(period: .month, date: monthSpread.date, calendar: calendar) == true)
        #expect(updatedTask.allAssignmentsForTesting.last?.status == .open)

        let yearKey = SpreadDataModelKey(spread: yearSpread, calendar: calendar)
        let monthKey = SpreadDataModelKey(spread: monthSpread, calendar: calendar)
        #expect(manager.dataModel[key: yearKey]?.tasks.isEmpty == true)
        #expect(manager.dataModel[key: monthKey]?.tasks.map(\.id) == [task.id])
    }

    /// Conditions: A day note is currently assigned to a month spread and a matching day spread is added.
    /// Expected: The note auto-migrates to the new day spread and leaves the month spread's current content.
    @Test @MainActor func testAddDaySpreadAutoMigratesMonthAssignedNoteToDay() async throws {
        let calendar = Self.testCalendar
        let noteDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: calendar)
        let note = DataModel.Note(
            title: "Month Assigned Note",
            date: noteDate,
            period: .day,
            currentAssignments: [Assignment(period: .month, date: noteDate, status: .active)]
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            spreadRepository: TestSpreadRepository(spreads: [monthSpread]),
            noteRepository: TestNoteRepository(notes: [note])
        )

        let daySpread = try await manager.addSpread(period: .day, date: noteDate)

        let updatedNote = try #require(manager.notes.first { $0.id == note.id })
        #expect(updatedNote.allAssignmentsForTesting.count == 2)
        #expect(updatedNote.allAssignmentsForTesting.first?.status == .migrated)
        #expect(updatedNote.allAssignmentsForTesting.last?.matches(period: .day, date: daySpread.date, calendar: calendar) == true)
        #expect(updatedNote.allAssignmentsForTesting.last?.status == .active)

        let monthKey = SpreadDataModelKey(spread: monthSpread, calendar: calendar)
        let dayKey = SpreadDataModelKey(spread: daySpread, calendar: calendar)
        #expect(manager.dataModel[key: monthKey]?.notes.isEmpty == true)
        #expect(manager.dataModel[key: dayKey]?.notes.map(\.id) == [note.id])
    }

    /// Conditions: Explicit spread creation resolves both a task and a note onto the new destination.
    /// Expected: The creation result reports exact auto-migration counts for feedback routing.
    @Test @MainActor func testCreateSpreadReturnsAutoMigrationSummary() async throws {
        let calendar = Self.testCalendar
        let entryDate = Self.testDate
        let task = DataModel.Task(
            title: "Inbox Task",
            date: entryDate,
            period: .day,
            currentAssignments: []
        )
        let note = DataModel.Note(
            title: "Inbox Note",
            date: entryDate,
            period: .day,
            currentAssignments: []
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: TestTaskRepository(tasks: [task]),
            noteRepository: TestNoteRepository(notes: [note])
        )

        let result = try await manager.createSpread(period: .day, date: entryDate)

        #expect(result.spread.period == .day)
        #expect(result.autoMigrationSummary?.taskCount == 1)
        #expect(result.autoMigrationSummary?.noteCount == 1)
    }

    /// Conditions: Explicit spread creation adds a destination but no eligible entries move.
    /// Expected: The creation result reports no auto-migration summary.
    @Test @MainActor func testCreateSpreadReturnsNilSummaryWhenNoEntriesMove() async throws {
        let calendar = Self.testCalendar
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate
        )

        let result = try await manager.createSpread(period: .day, date: Self.testDate)

        #expect(result.autoMigrationSummary == nil)
    }

    /// Conditions: A month-preferred task is currently assigned to a month spread and a matching day spread is added.
    /// Expected: The task stays on the month spread because the new day spread would exceed its preferred-period ceiling.
    @Test @MainActor func testAddDaySpreadDoesNotAutoMigrateMonthPreferredTask() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: calendar)
        let task = DataModel.Task(
            title: "Month Preferred Task",
            date: taskDate,
            period: .month,
            currentAssignments: [Assignment(period: .month, date: taskDate, status: .open)]
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: TestTaskRepository(tasks: [task]),
            spreadRepository: TestSpreadRepository(spreads: [monthSpread])
        )

        let daySpread = try await manager.addSpread(period: .day, date: taskDate)

        let updatedTask = try #require(manager.tasks.first { $0.id == task.id })
        #expect(updatedTask.allAssignmentsForTesting.count == 1)
        #expect(updatedTask.allAssignmentsForTesting.first?.matches(period: .month, date: monthSpread.date, calendar: calendar) == true)
        #expect(updatedTask.allAssignmentsForTesting.first?.status == .open)

        let monthKey = SpreadDataModelKey(spread: monthSpread, calendar: calendar)
        let dayKey = SpreadDataModelKey(spread: daySpread, calendar: calendar)
        #expect(manager.dataModel[key: monthKey]?.tasks.map(\.id) == [task.id])
        #expect(manager.dataModel[key: dayKey]?.tasks.isEmpty == true)
    }

    /// Conditions: Inbox task and note dates fall within a new multiday spread's range.
    /// Expected: Explicit multiday creation reconciles them into direct multiday ownership.
    @Test @MainActor func testAddMultidaySpreadDoesNotAutoAssignInboxEntries() async throws {
        let calendar = Self.testCalendar
        let entryDate = Self.testDate
        let task = DataModel.Task(
            title: "Inbox Task",
            date: entryDate,
            period: .day,
            currentAssignments: []
        )
        let note = DataModel.Note(
            title: "Inbox Note",
            date: entryDate,
            period: .day,
            currentAssignments: []
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            taskRepository: TestTaskRepository(tasks: [task]),
            noteRepository: TestNoteRepository(notes: [note])
        )

        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let multidaySpread = try await manager.addMultidaySpread(startDate: startDate, endDate: endDate)

        #expect(manager.inboxEntries.isEmpty)
        let updatedTask = try #require(manager.tasks.first { $0.id == task.id })
        let updatedNote = try #require(manager.notes.first { $0.id == note.id })
        #expect(updatedTask.allAssignmentsForTesting.count == 1)
        #expect(updatedNote.allAssignmentsForTesting.count == 1)
        #expect(updatedTask.allAssignmentsForTesting.first?.matches(spread: multidaySpread, calendar: calendar) == true)
        #expect(updatedTask.allAssignmentsForTesting.first?.spreadID == multidaySpread.id)
        #expect(updatedNote.allAssignmentsForTesting.first?.matches(spread: multidaySpread, calendar: calendar) == true)
        #expect(updatedNote.allAssignmentsForTesting.first?.spreadID == multidaySpread.id)
        #expect(manager.dataModel[.multiday]?[multidaySpread.date]?.tasks.map(\.id) == [task.id])
        #expect(manager.dataModel[.multiday]?[multidaySpread.date]?.notes.map(\.id) == [note.id])
    }

    /// Conditions: Add a spread to the manager.
    /// Expected: Data version increases.
    @Test @MainActor func testAddSpreadIncrementsDataVersion() async throws {
        let calendar = Self.testCalendar

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate
        )

        let initialVersion = manager.dataVersion

        try await manager.addSpread(period: .day, date: Self.testDate)

        #expect(manager.dataVersion > initialVersion)
    }

    /// Conditions: Add a day spread with an injected spread repository.
    /// Expected: Repository contains the saved day spread.
    @Test @MainActor func testAddSpreadPersistsSpreadToRepository() async throws {
        let calendar = Self.testCalendar
        let spreadRepo = TestSpreadRepository()

        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.testDate,
            spreadRepository: spreadRepo
        )

        try await manager.addSpread(period: .day, date: Self.testDate)

        let savedSpreads = await spreadRepo.getSpreads()
        #expect(savedSpreads.count == 1)
        #expect(savedSpreads.first?.period == .day)
    }

    /// Conditions: Add a spread for a different date than the inbox task.
    /// Expected: Task remains in the inbox.
    @Test @MainActor func testAddSpreadDoesNotAutoResolveUnmatchedEntries() async throws {
        let calendar = Self.testCalendar
        let taskDate = Self.testDate
        let differentDate = calendar.date(from: .init(year: 2026, month: 2, day: 15))!
        let task = DataModel.Task(
            title: "February Task",
            date: differentDate,
            period: .day,
            currentAssignments: []
        )
        let taskRepo = TestTaskRepository(tasks: [task])

        let manager = try await JournalManager(
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

    /// Conditions: One task and one note are unassigned, and one event exists.
    /// Expected: Inbox contains the task only — notes are never Inbox-eligible
    /// (`Note.isInboxEligible == false`, SPRD-247/248) and events use computed visibility,
    /// not assignments, so they're excluded too.
    @Test @MainActor func testInboxContainsOnlyUnassignedTasks() async throws {
        let task = DataModel.Task(title: "Task", date: Self.testDate, currentAssignments: [])
        let note = DataModel.Note(title: "Note", date: Self.testDate, currentAssignments: [])
        let event = DataModel.Event(title: "Event", startDate: Self.testDate, endDate: Self.testDate)
        let taskRepo = TestTaskRepository(tasks: [task])
        let noteRepo = TestNoteRepository(notes: [note])
        let eventRepo = TestEventRepository(events: [event])

        let manager = try await JournalManager(
            calendar: Self.testCalendar,
            today: Self.testDate,
            taskRepository: taskRepo,
            eventRepository: eventRepo,
            noteRepository: noteRepo
        )

        #expect(manager.inboxCount == 1)

        let taskInInbox = manager.inboxEntries.contains { $0.id == task.id }
        let noteInInbox = manager.inboxEntries.contains { $0.id == note.id }
        let eventInInbox = manager.inboxEntries.contains { $0.id == event.id }

        #expect(taskInInbox)
        #expect(!noteInInbox)
        #expect(!eventInInbox)
    }
}
