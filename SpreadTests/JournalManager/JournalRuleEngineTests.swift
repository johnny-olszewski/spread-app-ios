import Foundation
import Testing
@testable import Spread

struct JournalRuleEngineTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Data Model Building

    /// Setup: a task has a current day assignment, a current multiday assignment, and a migrated year-history assignment.
    /// Expected: targeted rebuild keys include only the live explicit assignment surfaces.
    @Test func testSpreadKeysForTaskExcludeMigratedHistoryAssignments() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 11)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let task = DataModel.Task(
            title: "Scoped",
            date: taskDate,
            period: .multiday,
            currentAssignments: [
                Assignment(period: .day, date: taskDate, status: .open),
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .open)
            ],
            migrationHistory: [
                Assignment(period: .year, date: taskDate, status: .migrated)
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let keys = engine.spreadKeys(for: task, spreads: [daySpread, multidaySpread])

        #expect(keys.count == 2)
        #expect(keys.contains(SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)))
        #expect(keys.contains(SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)))
        #expect(!keys.contains(SpreadDataModelKey(period: .year, date: taskDate, calendar: Self.calendar)))
    }

    /// Setup: a note has a current month assignment, a current multiday assignment, and a migrated year-history assignment.
    /// Expected: targeted rebuild keys include only the live explicit assignment surfaces.
    @Test func testSpreadKeysForNoteExcludeMigratedHistoryAssignments() {
        let noteDate = Self.makeDate(year: 2026, month: 1, day: 11)
        let monthSpread = DataModel.Spread(period: .month, date: noteDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let note = DataModel.Note(
            title: "Scoped Note",
            date: noteDate,
            period: .multiday,
            currentAssignments: [
                Assignment(period: .month, date: noteDate, status: .active),
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .active)
            ],
            migrationHistory: [
                Assignment(period: .year, date: noteDate, status: .migrated)
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let keys = engine.spreadKeys(for: note, spreads: [monthSpread, multidaySpread])

        #expect(keys.count == 2)
        #expect(keys.contains(SpreadDataModelKey(spread: monthSpread, calendar: Self.calendar)))
        #expect(keys.contains(SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)))
        #expect(!keys.contains(SpreadDataModelKey(period: .year, date: noteDate, calendar: Self.calendar)))
    }

    // MARK: - Inbox Resolution

    /// Setup: an unassigned open task, an unassigned cancelled task, and an unassigned note.
    /// Expected: the engine excludes the cancelled task (per-instance check) and the note
    /// (`Note.isInboxEligible == false`) — only the open task is returned. This is the
    /// confirmed, intentional divergence from the legacy `StandardInboxResolver`, which
    /// would also include the note.
    @Test func testInboxEntriesExcludesCancelledTasksAndAllNotes() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let openTask = DataModel.Task(title: "Open", date: dayDate, period: .day, currentAssignments: [])
        let cancelledTask = DataModel.Task(title: "Cancelled", date: dayDate, period: .day, status: .cancelled, currentAssignments: [])
        let note = DataModel.Note(title: "Note", date: dayDate, period: .day, currentAssignments: [])

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let entries = engine.inboxEntries(
            entries: [openTask, cancelledTask, note],
            spreads: []
        )

        #expect(entries.map(\.id) == [openTask.id])
    }

    /// Setup: a task has only a migrated assignment that matches an existing spread.
    /// Expected: the engine keeps it in Inbox because migrated-only history is not an
    /// active matching assignment. Parity with the legacy `StandardInboxResolver`.
    @Test func testInboxEntriesTreatsMigratedOnlyAssignmentsAsInboxEligible() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Migrated only",
            date: dayDate,
            period: .day,
            migrationHistory: [Assignment(period: .day, date: dayDate, status: .migrated)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let entries = engine.inboxEntries(entries: [task], spreads: [spread])

        #expect(entries.map(\.id) == [task.id])
    }

    /// Setup: a task has an active assignment matching an existing spread.
    /// Expected: the task is excluded from Inbox. Parity with the legacy
    /// `StandardInboxResolver` for tasks specifically.
    @Test func testInboxEntriesExcludesTaskWithMatchingActiveAssignment() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Assigned task",
            date: dayDate,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let entries = engine.inboxEntries(entries: [task], spreads: [daySpread])

        #expect(entries.isEmpty)
    }

    // MARK: - Migration Planning

    /// Setup: a task currently assigned to a year spread, evaluated against both a month and
    /// a day destination.
    /// Expected: only the day destination (most granular valid) yields a candidate, sourced
    /// from the year spread.
    @Test func testMigrationCandidatesUsesMostGranularValidDestination() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Day task",
            date: taskDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)

        let monthCandidates = engine.migrationCandidates(
            tasks: [task],
            spreads: [yearSpread, monthSpread, daySpread],
            to: monthSpread
        )
        let dayCandidates = engine.migrationCandidates(
            tasks: [task],
            spreads: [yearSpread, monthSpread, daySpread],
            to: daySpread
        )

        #expect(monthCandidates.isEmpty)
        #expect(dayCandidates.map(\.entry.id) == [task.id])
        #expect(dayCandidates.first?.sourceSpread?.id == yearSpread.id)
    }

    /// Setup: three tasks with year, month, and Inbox sources, evaluated against a day destination.
    /// Expected: parent-hierarchy candidates exclude the Inbox-origin task and sort alphabetically.
    @Test func testParentHierarchyMigrationCandidatesExcludeInboxAndSortAlphabetically() {
        let taskDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)

        let yearTask = DataModel.Task(
            title: "Zulu",
            date: taskDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )
        let monthTask = DataModel.Task(
            title: "Alpha",
            date: taskDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .month, date: taskDate, status: .open)]
        )
        let inboxTask = DataModel.Task(
            title: "Inbox",
            date: taskDate,
            period: .day,
            status: .open
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let candidates = engine.parentHierarchyMigrationCandidates(
            tasks: [yearTask, monthTask, inboxTask],
            spreads: [yearSpread, monthSpread, daySpread],
            to: daySpread
        )

        #expect(candidates.map(\.entry.title) == ["Alpha", "Zulu"])
        #expect(candidates.allSatisfy { $0.sourceSpread != nil })
    }

    /// Setup: a task has an open month assignment and a completed day assignment.
    /// Expected: `currentDestinationSpread` (open-only) and `currentDisplayedSpread`
    /// (non-migrated) diverge — destination is the month spread, displayed is the day spread.
    @Test func testCurrentDisplayedSpreadCanDifferFromCurrentDestinationSpread() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Mixed status",
            date: taskDate,
            period: .day,
            status: .open,
            currentAssignments: [
                Assignment(period: .month, date: taskDate, status: .open),
                Assignment(period: .day, date: taskDate, status: .complete)
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)

        let destination = engine.currentDestinationSpread(
            for: task,
            spreads: [monthSpread, daySpread],
            excluding: nil
        )
        let displayed = engine.currentDisplayedSpread(
            for: task,
            spreads: [monthSpread, daySpread],
            excluding: nil
        )

        #expect(destination?.id == monthSpread.id)
        #expect(displayed?.id == daySpread.id)
    }

    /// Setup: a task on a year spread, evaluated for an inline migration affordance.
    /// Expected: the most granular valid destination (a day spread) is returned.
    @Test func testMigrationDestinationPrefersMoreGranularSpread() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Move me",
            date: taskDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)

        let destination = engine.migrationDestination(
            for: task,
            on: yearSpread,
            spreads: [yearSpread, daySpread]
        )

        #expect(destination?.id == daySpread.id)
    }

    // MARK: - Overdue Evaluation

    /// Setup: an unassigned open task whose preferred date is yesterday.
    /// Expected: the task reports as overdue, sourced from the Inbox.
    @Test func testOverdueTaskItemsReturnsInboxSourceForOverdueUnassignedDayTask() {
        let today = Self.makeDate(year: 2026, month: 4, day: 12)
        let task = DataModel.Task(
            title: "Inbox overdue",
            date: Self.makeDate(year: 2026, month: 4, day: 11),
            period: .day,
            status: .open
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let items = engine.overdueTaskItems(tasks: [task], spreads: [])

        #expect(items.map(\.task.id) == [task.id])
        #expect(items.first?.sourceKey.id == "inbox")
    }

    /// Setup: a task currently assigned to an overdue month spread, but with a future preferred date.
    /// Expected: the spread's date drives the overdue source, not the task's own preferred date.
    @Test func testOverdueTaskItemsUsesCurrentDestinationSpreadAsOverdueSource() {
        let today = Self.makeDate(year: 2026, month: 5, day: 3)
        let monthDate = Self.makeDate(year: 2026, month: 4, day: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Spread overdue",
            date: Self.makeDate(year: 2026, month: 5, day: 20),
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .month, date: monthDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let items = engine.overdueTaskItems(tasks: [task], spreads: [monthSpread])

        #expect(items.first?.sourceKey.id == "spread-\(monthSpread.id.uuidString)")
    }

    /// Setup: one task overdue by month boundary, one task not yet overdue by year boundary.
    /// Expected: only the month-boundary task is reported overdue.
    @Test func testOverdueTaskItemsUsesMonthAndYearBoundaryRules() {
        let today = Self.makeDate(year: 2026, month: 5, day: 1)
        let overdueMonthTask = DataModel.Task(
            title: "Month overdue",
            date: Self.makeDate(year: 2026, month: 4, day: 10),
            period: .month,
            status: .open
        )
        let notYetOverdueYearTask = DataModel.Task(
            title: "Year active",
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            period: .year,
            status: .open
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let items = engine.overdueTaskItems(
            tasks: [overdueMonthTask, notYetOverdueYearTask],
            spreads: []
        )

        #expect(items.map(\.task.id) == [overdueMonthTask.id])
    }

    /// Setup: a completed task, a cancelled task, and an open multiday task, all with past dates.
    /// Expected: none are reported overdue — completed/cancelled tasks are excluded by status,
    /// and multiday tasks are never considered overdue.
    @Test func testOverdueTaskItemsExcludesCompletedCancelledAndMultidayTasks() {
        let today = Self.makeDate(year: 2026, month: 4, day: 12)
        let completeTask = DataModel.Task(
            title: "Complete",
            date: Self.makeDate(year: 2026, month: 4, day: 10),
            period: .day,
            status: .complete
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled",
            date: Self.makeDate(year: 2026, month: 4, day: 10),
            period: .day,
            status: .cancelled
        )
        let multidayTask = DataModel.Task(
            title: "Multiday",
            date: Self.makeDate(year: 2026, month: 4, day: 1),
            period: .multiday,
            status: .open
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let items = engine.overdueTaskItems(
            tasks: [completeTask, cancelledTask, multidayTask],
            spreads: []
        )

        #expect(items.isEmpty)
    }

    /// Setup: a task with an open multiday assignment whose range has already ended.
    /// Expected: the task is overdue, sourced from the multiday spread.
    @Test func testOverdueTaskItemsUsesAssignedMultidayEndDateForOverdueChecks() {
        let today = Self.makeDate(year: 2026, month: 4, day: 12)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 8),
            endDate: Self.makeDate(year: 2026, month: 4, day: 11),
            calendar: Self.calendar
        )
        let task = DataModel.Task(
            title: "Range overdue",
            date: Self.makeDate(year: 2026, month: 4, day: 9),
            period: .multiday,
            status: .open,
            currentAssignments: [
                Assignment(
                    period: .multiday,
                    date: multidaySpread.date,
                    spreadID: multidaySpread.id,
                    status: .open
                )
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let items = engine.overdueTaskItems(tasks: [task], spreads: [multidaySpread])

        #expect(items.count == 1)
        #expect(items.first?.sourceKey.id == "spread-\(multidaySpread.id.uuidString)")
    }

    /// Setup: a task with an open multiday assignment whose range has not yet ended.
    /// Expected: the task is not overdue.
    @Test func testOverdueTaskItemsDoesNotMarkAssignedMultidayTaskOverdueBeforeRangeEnds() {
        let today = Self.makeDate(year: 2026, month: 4, day: 11)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 4, day: 8),
            endDate: Self.makeDate(year: 2026, month: 4, day: 11),
            calendar: Self.calendar
        )
        let task = DataModel.Task(
            title: "Range active",
            date: Self.makeDate(year: 2026, month: 4, day: 9),
            period: .multiday,
            status: .open,
            currentAssignments: [
                Assignment(
                    period: .multiday,
                    date: multidaySpread.date,
                    spreadID: multidaySpread.id,
                    status: .open
                )
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let items = engine.overdueTaskItems(tasks: [task], spreads: [multidaySpread])

        #expect(items.isEmpty)
    }

    // MARK: - Assignment Reconciliation

    /// Setup: a task with an open year assignment, reconciled against no existing spreads.
    /// Expected: falls back to Inbox by migrating the active assignment to history.
    @Test func testReconcilePreferredAssignmentForTaskFallsBackToInboxByMigratingActiveAssignments() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let task = DataModel.Task(
            title: "Inbox fallback",
            date: taskDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        engine.reconcilePreferredAssignment(for: task, in: [])

        #expect(task.allAssignmentsForTesting.count == 1)
        #expect(task.allAssignmentsForTesting.first?.status == .migrated)
    }

    /// Setup: a complete task with a migrated-history month assignment matching an existing month spread.
    /// Expected: the existing destination assignment is reused and its status preserved as complete.
    @Test func testReconcilePreferredAssignmentForTaskReusesExistingDestinationAndPreservesCompleteStatus() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Complete",
            date: taskDate,
            period: .month,
            status: .complete,
            currentAssignments: [
                Assignment(period: .year, date: taskDate, status: .open)
            ],
            migrationHistory: [
                Assignment(period: .month, date: taskDate, status: .migrated)
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        engine.reconcilePreferredAssignment(for: task, in: [monthSpread])

        #expect(task.allAssignmentsForTesting[0].status == .migrated)
        #expect(task.allAssignmentsForTesting[1].status == .complete)
    }

    /// Setup: a note with an active year assignment, reconciled against a matching day spread.
    /// Expected: the year assignment is migrated to history and a new active day assignment is created.
    @Test func testReconcilePreferredAssignmentForNoteCreatesDestinationAssignmentAfterMigratingHistory() {
        let noteDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Note",
            date: noteDate,
            period: .day,
            currentAssignments: [Assignment(period: .year, date: noteDate, status: .active)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        engine.reconcilePreferredAssignment(for: note, in: [daySpread])

        #expect(note.allAssignmentsForTesting.count == 2)
        #expect(note.allAssignmentsForTesting[0].status == .migrated)
        #expect(note.allAssignmentsForTesting[1].status == .active)
        #expect(note.allAssignmentsForTesting[1].period == .day)
    }

    /// Setup: a note with a migrated-history day assignment matching an existing day spread.
    /// Expected: the existing destination assignment is reused and reactivated.
    @Test func testReconcilePreferredAssignmentForNoteReusesExistingDestinationAssignment() {
        let noteDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: noteDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Note",
            date: noteDate,
            period: .day,
            currentAssignments: [
                Assignment(period: .month, date: noteDate, status: .active)
            ],
            migrationHistory: [
                Assignment(period: .day, date: noteDate, status: .migrated)
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        engine.reconcilePreferredAssignment(for: note, in: [daySpread])

        #expect(note.allAssignmentsForTesting[0].status == .migrated)
        #expect(note.allAssignmentsForTesting[1].status == .active)
    }
}
