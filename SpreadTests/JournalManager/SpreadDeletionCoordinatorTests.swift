import Foundation
import Testing
@testable import Spread

/// Tests for `SpreadDeletionCoordinator`, constructed directly with `Test*Repository`
/// doubles and a plain `Calendar` — no `JournalManager` involved. Mirrors the
/// deletion/reassignment scenarios already exercised through `JournalManager`'s existing
/// black-box suite (`SpreadDeletionTests`), excluding the 3 scenarios that are
/// `JournalManager`-index-specific (`dataVersion`, `dataModel` rebuild, in-memory rollback
/// on repository failure) — those stay as `JournalManager`-only tests since they test
/// observed-state behavior the coordinator doesn't own. No legacy `Standard*` counterpart
/// exists to parity-test against.
@MainActor
struct SpreadDeletionCoordinatorTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    private func makeCoordinator(spreads: [DataModel.Spread] = []) -> (coordinator: SpreadDeletionCoordinator, spreadRepository: TestSpreadRepository) {
        let spreadRepository = TestSpreadRepository(spreads: spreads)
        let coordinator = SpreadDeletionCoordinator(
            spreadRepository: spreadRepository,
            taskRepository: TestTaskRepository(),
            noteRepository: TestNoteRepository(),
            ruleEngine: JournalRuleEngine(calendar: Self.calendar),
            calendar: Self.calendar
        )
        return (coordinator, spreadRepository)
    }

    // MARK: - Basic Spread Deletion

    /// Conditions: A day spread is deleted and a parent month spread exists.
    /// Expected: The task is reassigned to the month spread.
    @Test func testDeleteSpreadReassignsTasksToParent() async throws {
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Test Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let coordinator = SpreadDeletionCoordinator(
            spreadRepository: TestSpreadRepository(spreads: [monthSpread, daySpread]),
            taskRepository: TestTaskRepository(),
            noteRepository: TestNoteRepository(),
            ruleEngine: JournalRuleEngine(calendar: Self.calendar),
            calendar: Self.calendar
        )

        let result = try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [task], notes: [])

        #expect(result.mutatedTasks.map(\.id) == [task.id])
        let monthAssignment = task.allAssignmentsForTesting.first { $0.period == .month }
        #expect(monthAssignment?.status == .open)
    }

    /// Conditions: A day spread carrying a timed task is deleted; the task's only viable
    /// replacement is the parent month spread (SPRD-298: deleting a task's day spread always
    /// leaves day period, since a day's only parent is month).
    /// Expected: `scheduledTime` is cleared to `nil` and `scheduledTimeUpdatedAt` is stamped.
    @Test func testDeleteSpreadClearsScheduledTimeOnReassignmentToMonth() async throws {
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let scheduledTime = Self.calendar.date(byAdding: .hour, value: 14, to: taskDate)!
        let task = DataModel.Task(
            title: "Test Task", scheduledTime: scheduledTime, date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [monthSpread, daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [task], notes: [])

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Conditions: A day spread carrying a timed task is deleted and no parent spread exists.
    /// Expected: the task falls to Inbox and `scheduledTime` is cleared to `nil`, stamping
    /// `scheduledTimeUpdatedAt`.
    @Test func testDeleteSpreadClearsScheduledTimeOnFallbackToInbox() async throws {
        let taskDate = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let scheduledTime = Self.calendar.date(byAdding: .hour, value: 9, to: taskDate)!
        let task = DataModel.Task(
            title: "Test Task", scheduledTime: scheduledTime, date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [daySpread], tasks: [task], notes: [])

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Conditions: A day spread is deleted and a parent month spread exists.
    /// Expected: The note is reassigned to the month spread.
    @Test func testDeleteSpreadReassignsNotesToParent() async throws {
        let noteDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Test Note", date: noteDate, period: .day, status: .active,
            currentAssignments: [Assignment(period: .day, date: noteDate, status: .active)]
        )
        let coordinator = SpreadDeletionCoordinator(
            spreadRepository: TestSpreadRepository(spreads: [monthSpread, daySpread]),
            taskRepository: TestTaskRepository(),
            noteRepository: TestNoteRepository(),
            ruleEngine: JournalRuleEngine(calendar: Self.calendar),
            calendar: Self.calendar
        )

        let result = try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [], notes: [note])

        #expect(result.mutatedNotes.map(\.id) == [note.id])
        let monthAssignment = note.allAssignmentsForTesting.first { $0.period == .month }
        #expect(monthAssignment?.status == .active)
    }

    /// Conditions: A day spread is deleted and no parent spread exists.
    /// Expected: The task ends up with no current assignment (Inbox).
    @Test func testDeleteSpreadSendsTasksToInboxWhenNoParent() async throws {
        let taskDate = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Test Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [daySpread], tasks: [task], notes: [])

        #expect(task.currentAssignments.isEmpty)
    }

    // MARK: - History Preservation

    /// Conditions: A spread is deleted.
    /// Expected: The original assignment is preserved in history, marked `.migrated`.
    @Test func testDeleteSpreadPreservesAssignmentHistory() async throws {
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Test Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [monthSpread, daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [task], notes: [])

        #expect(task.allAssignmentsForTesting.count == 2)
        let dayAssignment = task.allAssignmentsForTesting.first { $0.period == .day }
        #expect(dayAssignment?.status == .migrated)
    }

    // MARK: - Entry Preservation

    /// Conditions: A spread is deleted that has completed tasks.
    /// Expected: Completed tasks are reassigned with their status preserved, not deleted.
    @Test func testDeleteSpreadReassignsCompletedTasks() async throws {
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let completedTask = DataModel.Task(
            title: "Completed Task", date: taskDate, period: .day, status: .complete,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .complete)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [monthSpread, daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [completedTask], notes: [])

        let monthAssignment = completedTask.allAssignmentsForTesting.first { $0.period == .month }
        #expect(monthAssignment?.status == .complete)
    }

    /// Conditions: A spread is deleted with a task and note assigned to it.
    /// Expected: Both entries are returned as mutated, never deleted from their repositories.
    @Test func testDeleteSpreadNeverDeletesEntries() async throws {
        let taskDate = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Test Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let note = DataModel.Note(
            title: "Test Note", date: taskDate, period: .day, status: .active,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .active)]
        )
        let taskRepository = TestTaskRepository(tasks: [task])
        let noteRepository = TestNoteRepository(notes: [note])
        let coordinator = SpreadDeletionCoordinator(
            spreadRepository: TestSpreadRepository(spreads: [daySpread]),
            taskRepository: taskRepository,
            noteRepository: noteRepository,
            ruleEngine: JournalRuleEngine(calendar: Self.calendar),
            calendar: Self.calendar
        )

        try await coordinator.deleteSpread(daySpread, spreads: [daySpread], tasks: [task], notes: [note])

        #expect(await taskRepository.getTasks().count == 1)
        #expect(await noteRepository.getNotes().count == 1)
    }

    // MARK: - Spread Removal

    /// Conditions: A spread is deleted.
    /// Expected: The spread is removed from the spread repository.
    @Test func testDeleteSpreadPersistsDeletion() async throws {
        let taskDate = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let (coordinator, spreadRepository) = makeCoordinator(spreads: [daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [daySpread], tasks: [], notes: [])

        let savedSpreads = await spreadRepository.getSpreads()
        #expect(savedSpreads.isEmpty)
    }

    // MARK: - Parent Hierarchy

    /// Conditions: A day spread is deleted; both a month (immediate parent) and year
    /// (grandparent) spread exist.
    /// Expected: The task is reassigned to month, not year.
    @Test func testDeleteSpreadReassignsToImmediateParent() async throws {
        let taskDate = Self.testDate
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Test Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [yearSpread, monthSpread, daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [yearSpread, monthSpread, daySpread], tasks: [task], notes: [])

        #expect(task.allAssignmentsForTesting.first { $0.period == .month } != nil)
        #expect(task.allAssignmentsForTesting.first { $0.period == .year } == nil)
    }

    /// Conditions: A month spread is deleted; only a year spread exists (no day spread).
    /// Expected: The task is reassigned to the year (grandparent) spread.
    @Test func testDeleteSpreadReassignsToGrandparentWhenNoParent() async throws {
        let taskDate = Self.testDate
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Test Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .month, date: taskDate, status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [yearSpread, monthSpread])

        try await coordinator.deleteSpread(monthSpread, spreads: [yearSpread, monthSpread], tasks: [task], notes: [])

        let yearAssignment = task.allAssignmentsForTesting.first { $0.period == .year }
        #expect(yearAssignment?.status == .open)
    }

    // MARK: - Multiple Entries

    /// Conditions: A spread is deleted with multiple tasks assigned to it.
    /// Expected: All tasks are reassigned to the parent spread.
    @Test func testDeleteSpreadReassignsMultipleTasks() async throws {
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task1 = DataModel.Task(
            title: "Task 1", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let task2 = DataModel.Task(
            title: "Task 2", date: taskDate, period: .day, status: .complete,
            currentAssignments: [Assignment(period: .day, date: taskDate, status: .complete)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [monthSpread, daySpread])

        let result = try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [task1, task2], notes: [])

        #expect(result.mutatedTasks.count == 2)
        for task in result.mutatedTasks {
            #expect(task.allAssignmentsForTesting.first { $0.period == .month } != nil)
        }
    }

    // MARK: - Migrated Entries

    /// Conditions: A spread is deleted that has an entry whose only assignment for that
    /// spread is already in migration history.
    /// Expected: The migrated entry is still reassigned (not lost/skipped).
    @Test func testDeleteSpreadReassignsMigratedEntries() async throws {
        let taskDate = Self.testDate
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let migratedTask = DataModel.Task(
            title: "Migrated Task", date: taskDate, period: .day, status: .open,
            migrationHistory: [Assignment(period: .day, date: taskDate, status: .migrated)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [monthSpread, daySpread])

        try await coordinator.deleteSpread(daySpread, spreads: [monthSpread, daySpread], tasks: [migratedTask], notes: [])

        #expect(migratedTask.allAssignmentsForTesting.first { $0.period == .month } != nil)
    }

    // MARK: - No-Match Entries

    /// Conditions: A spread is deleted; a task/note has no assignment (current or history)
    /// matching it.
    /// Expected: The entry is left untouched and not included in the mutated results.
    @Test func testDeleteSpreadSkipsUnaffectedEntries() async throws {
        let taskDate = Self.testDate
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let otherDaySpread = DataModel.Spread(period: .day, date: taskDate.addingTimeInterval(86400), calendar: Self.calendar)
        let unaffectedTask = DataModel.Task(
            title: "Unaffected", date: taskDate, period: .day, status: .open,
            currentAssignments: [Assignment(period: .day, date: taskDate.addingTimeInterval(86400), status: .open)]
        )
        let (coordinator, _) = makeCoordinator(spreads: [daySpread, otherDaySpread])

        let result = try await coordinator.deleteSpread(daySpread, spreads: [daySpread, otherDaySpread], tasks: [unaffectedTask], notes: [])

        #expect(result.mutatedTasks.isEmpty)
    }

    // MARK: - Multiday Deletion Fallback

    /// Conditions: A multiday spread is deleted; a task assigned to it has a preferred day
    /// date matching an existing day spread (not a parent-hierarchy relationship — multiday
    /// ranges have no parent-hierarchy concept).
    /// Expected: the task falls back to its own best-matching non-multiday spread, not Inbox.
    @Test func testDeleteMultidaySpreadFallsBackToTasksOwnBestSpread() async throws {
        let startDate = Self.testDate
        let endDate = Self.calendar.date(byAdding: .day, value: 2, to: startDate)!
        let taskDate = Self.calendar.date(byAdding: .day, value: 1, to: startDate)!
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", date: taskDate, period: .day, status: .open,
            currentAssignments: [
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .open)
            ]
        )
        let (coordinator, _) = makeCoordinator(spreads: [multidaySpread, daySpread])

        try await coordinator.deleteSpread(multidaySpread, spreads: [multidaySpread, daySpread], tasks: [task], notes: [])

        let dayAssignment = task.allAssignmentsForTesting.first { $0.matches(spread: daySpread, calendar: Self.calendar) }
        #expect(dayAssignment?.status == .open)
    }

    /// Conditions: A multiday spread is deleted; an assigned task's preferred date has no
    /// matching spread of any granularity.
    /// Expected: the task falls back to Inbox (migrated-only, no replacement assignment).
    @Test func testDeleteMultidaySpreadFallsBackToInboxWhenNoMatchExists() async throws {
        let startDate = Self.testDate
        let endDate = Self.calendar.date(byAdding: .day, value: 2, to: startDate)!
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", date: startDate, period: .day, status: .open,
            currentAssignments: [
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .open)
            ]
        )
        let (coordinator, _) = makeCoordinator(spreads: [multidaySpread])

        try await coordinator.deleteSpread(multidaySpread, spreads: [multidaySpread], tasks: [task], notes: [])

        #expect(task.allAssignmentsForTesting.allSatisfy { $0.status == .migrated })
    }
}
