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

    /// Setup: a day spread has one directly assigned task and one migrated-history task.
    /// Expected: the rule engine includes only the current non-migrated assignment.
    @Test func testBuilderExcludesMigratedHistoryFromExplicitSpreadContent() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)

        let openTask = DataModel.Task(
            title: "Open",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let migratedTask = DataModel.Task(
            title: "Migrated",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .migrated)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let model = engine.buildDataModel(
            spreads: [daySpread],
            tasks: [openTask, migratedTask],
            notes: [],
            events: []
        )

        let dayModel = model[.day]?[Period.day.normalizeDate(dayDate, calendar: Self.calendar)]
        #expect(dayModel?.tasks.map(\.id) == [openTask.id])
    }

    /// Setup: a multiday spread spans January 10 through January 12 with explicitly assigned and merely in-range entries.
    /// Expected: only entries explicitly assigned to the multiday spread appear on it.
    @Test func testBuilderAggregatesOnlyEntriesInsideMultidayRange() {
        let startDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let endDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)

        let assignedTask = DataModel.Task(
            title: "Assigned",
            date: Self.makeDate(year: 2026, month: 1, day: 11),
            period: .multiday,
            assignments: [
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .open)
            ]
        )
        let assignedNote = DataModel.Note(
            title: "Assigned Note",
            date: endDate,
            period: .multiday,
            assignments: [
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .active)
            ]
        )
        let inRangeUnassignedTask = DataModel.Task(
            title: "Preferred Only",
            date: Self.makeDate(year: 2026, month: 1, day: 11),
            period: .day
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let model = engine.buildDataModel(
            spreads: [multidaySpread],
            tasks: [assignedTask, inRangeUnassignedTask],
            notes: [assignedNote],
            events: []
        )

        let spreadModel = model[.multiday]?[multidaySpread.date]
        #expect(spreadModel?.tasks.map(\.id) == [assignedTask.id])
        #expect(spreadModel?.notes.map(\.id) == [assignedNote.id])
    }

    /// Setup: a day spread and a multiday spread share a date with overlapping and non-overlapping events.
    /// Expected: the rule engine uses computed event visibility for both explicit and multiday spreads.
    @Test func testBuilderUsesEventVisibilityRulesForExplicitAndMultidaySpreads() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 11),
            endDate: Self.makeDate(year: 2026, month: 1, day: 13),
            calendar: Self.calendar
        )

        let overlappingEvent = DataModel.Event(title: "Overlap", startDate: dayDate, endDate: dayDate)
        let outOfRangeEvent = DataModel.Event(
            title: "Later",
            startDate: Self.makeDate(year: 2026, month: 1, day: 20),
            endDate: Self.makeDate(year: 2026, month: 1, day: 20)
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let model = engine.buildDataModel(
            spreads: [daySpread, multidaySpread],
            tasks: [],
            notes: [],
            events: [overlappingEvent, outOfRangeEvent]
        )

        let dayModel = model[.day]?[Period.day.normalizeDate(dayDate, calendar: Self.calendar)]
        let multidayModel = model[.multiday]?[multidaySpread.date]
        #expect(dayModel?.events.map(\.id) == [overlappingEvent.id])
        #expect(multidayModel?.events.map(\.id) == [overlappingEvent.id])
    }

    /// Setup: a day spread has one open task and a targeted rebuild is requested for its key.
    /// Expected: the targeted rebuild matches the equivalent slice of a full build.
    @Test func testBuildSpreadDataModelMatchesFullBuildForExplicitSpread() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Open",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let fullModel = engine.buildDataModel(
            spreads: [daySpread],
            tasks: [task],
            notes: [],
            events: []
        )
        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let targeted = engine.buildSpreadDataModel(
            for: key,
            spreads: [daySpread],
            tasks: [task],
            notes: [],
            events: []
        )

        #expect(targeted?.spread.id == fullModel[key: key]?.spread.id)
        #expect(targeted?.tasks.map(\.id) == fullModel[key: key]?.tasks.map(\.id))
    }

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
            assignments: [
                Assignment(period: .year, date: taskDate, status: .migrated),
                Assignment(period: .day, date: taskDate, status: .open),
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .open)
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
            assignments: [
                Assignment(period: .year, date: noteDate, status: .migrated),
                Assignment(period: .month, date: noteDate, status: .active),
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .active)
            ]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let keys = engine.spreadKeys(for: note, spreads: [monthSpread, multidaySpread])

        #expect(keys.count == 2)
        #expect(keys.contains(SpreadDataModelKey(spread: monthSpread, calendar: Self.calendar)))
        #expect(keys.contains(SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)))
        #expect(!keys.contains(SpreadDataModelKey(period: .year, date: noteDate, calendar: Self.calendar)))
    }

    /// Setup: a mixed set of spreads/tasks/notes/events exercised against both the legacy
    /// `ConventionalJournalDataModelBuilder` and the new `JournalRuleEngine`.
    /// Expected: both produce an identical `JournalDataModel`, proving data-model-building
    /// parity between the legacy and consolidated implementations.
    @Test func testBuildDataModelMatchesLegacyBuilder() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let task = DataModel.Task(
            title: "Open",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let note = DataModel.Note(
            title: "Note",
            date: multidaySpread.date,
            period: .multiday,
            assignments: [
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .active)
            ]
        )
        let event = DataModel.Event(title: "Event", startDate: dayDate, endDate: dayDate)

        let legacyBuilder = ConventionalJournalDataModelBuilder(calendar: Self.calendar)
        let legacyModel = legacyBuilder.buildDataModel(
            spreads: [daySpread, multidaySpread],
            tasks: [task],
            notes: [note],
            events: [event]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let engineModel = engine.buildDataModel(
            spreads: [daySpread, multidaySpread],
            tasks: [task],
            notes: [note],
            events: [event]
        )

        let dayKey = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let multidayKey = SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)
        #expect(legacyModel[key: dayKey]?.tasks.map(\.id) == engineModel[key: dayKey]?.tasks.map(\.id))
        #expect(legacyModel[key: dayKey]?.events.map(\.id) == engineModel[key: dayKey]?.events.map(\.id))
        #expect(legacyModel[key: multidayKey]?.notes.map(\.id) == engineModel[key: multidayKey]?.notes.map(\.id))
    }

    // MARK: - Inbox Resolution

    /// Setup: an unassigned open task, an unassigned cancelled task, and an unassigned note.
    /// Expected: the engine excludes the cancelled task (per-instance check) and the note
    /// (`Note.isInboxEligible == false`) — only the open task is returned. This is the
    /// confirmed, intentional divergence from the legacy `StandardInboxResolver`, which
    /// would also include the note.
    @Test func testInboxEntriesExcludesCancelledTasksAndAllNotes() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let openTask = DataModel.Task(title: "Open", date: dayDate, period: .day, assignments: [])
        let cancelledTask = DataModel.Task(title: "Cancelled", date: dayDate, period: .day, status: .cancelled, assignments: [])
        let note = DataModel.Note(title: "Note", date: dayDate, period: .day, assignments: [])

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
            assignments: [Assignment(period: .day, date: dayDate, status: .migrated)]
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
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let entries = engine.inboxEntries(entries: [task], spreads: [daySpread])

        #expect(entries.isEmpty)
    }

    /// Setup: the same task fixtures from `InboxResolverTests` run through both the legacy
    /// `StandardInboxResolver` and `JournalRuleEngine.inboxEntries`.
    /// Expected: identical output for tasks — full parity for the entry type both
    /// implementations agree is Inbox-eligible.
    @Test func testInboxEntriesMatchesLegacyResolverForTasks() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let openTask = DataModel.Task(title: "Open", date: dayDate, period: .day, assignments: [])
        let cancelledTask = DataModel.Task(title: "Cancelled", date: dayDate, period: .day, status: .cancelled, assignments: [])
        let assignedTask = DataModel.Task(
            title: "Assigned",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )

        let legacyResolver = StandardInboxResolver(calendar: Self.calendar)
        let legacyEntries = legacyResolver.inboxEntries(
            tasks: [openTask, cancelledTask, assignedTask],
            notes: [],
            spreads: [spread]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let engineEntries = engine.inboxEntries(
            entries: [openTask, cancelledTask, assignedTask],
            spreads: [spread]
        )

        #expect(legacyEntries.map(\.id) == engineEntries.map(\.id))
    }

    /// Setup: an unassigned note run through both the legacy `StandardInboxResolver` and
    /// `JournalRuleEngine.inboxEntries`.
    /// Expected: divergence, not parity — the legacy resolver includes the note (it has no
    /// per-type Inbox eligibility concept), while the engine excludes it via
    /// `Note.isInboxEligible == false` (SPRD-247's already-shipped flag value). This is the
    /// confirmed, intentional behavior change flagged in SPRD-248's plan.md notes; this test
    /// locks in that divergence is real and deliberate, not a missed case.
    @Test func testInboxEntriesDivergesFromLegacyResolverForUnassignedNotes() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let note = DataModel.Note(title: "Note", date: dayDate, period: .day, assignments: [])

        let legacyResolver = StandardInboxResolver(calendar: Self.calendar)
        let legacyEntries = legacyResolver.inboxEntries(tasks: [], notes: [note], spreads: [])
        #expect(legacyEntries.map(\.id) == [note.id])

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let engineEntries = engine.inboxEntries(entries: [note], spreads: [])
        #expect(engineEntries.isEmpty)
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
            assignments: [Assignment(period: .year, date: taskDate, status: .open)]
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
            assignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )
        let monthTask = DataModel.Task(
            title: "Alpha",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [Assignment(period: .month, date: taskDate, status: .open)]
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
            assignments: [
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
            assignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)

        let destination = engine.migrationDestination(
            for: task,
            on: yearSpread,
            spreads: [yearSpread, daySpread]
        )

        #expect(destination?.id == daySpread.id)
    }

    /// Setup: a multiday spread crossing a month/year boundary.
    /// Expected: `currentDestinationSpread`/`currentDisplayedSpread` parity-check the simpler
    /// `sourceSpread?.period.granularityRank ?? 0` rank computation against the legacy
    /// `TaskReviewSourceKey`-based computation, by running the same scenario from
    /// `testMigrationCandidatesUsesMostGranularValidDestination` through both implementations.
    @Test func testMigrationCandidatesMatchesLegacyPlanner() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Day task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )

        let legacyPlanner = StandardMigrationPlanner(calendar: Self.calendar)
        let legacyCandidates = legacyPlanner.migrationCandidates(
            tasks: [task],
            spreads: [yearSpread, monthSpread, daySpread],
            to: daySpread
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let engineCandidates = engine.migrationCandidates(
            tasks: [task],
            spreads: [yearSpread, monthSpread, daySpread],
            to: daySpread
        )

        #expect(legacyCandidates.map(\.task.id) == engineCandidates.map(\.entry.id))
        #expect(legacyCandidates.map(\.sourceSpread?.id) == engineCandidates.map(\.sourceSpread?.id))
        #expect(legacyCandidates.map(\.destination.id) == engineCandidates.map(\.destination.id))
    }

    /// Setup: a multiday destination spread spanning December 29 - January 4, with one task
    /// sourced from December and one from January, run through both the legacy
    /// `StandardMigrationPlanner` and `JournalRuleEngine`.
    /// Expected: identical output — this seam was ported verbatim (no behavior change was
    /// authorized for this task), so both implementations count every month/year the range
    /// touches as a parent, including both December and January.
    @Test func testParentHierarchyMigrationCandidatesForMultidayMatchesLegacyPlanner() {
        let decemberMonthDate = Self.makeDate(year: 2025, month: 12, day: 1)
        let januaryMonthDate = Self.makeDate(year: 2026, month: 1, day: 1)
        let decemberMonthSpread = DataModel.Spread(period: .month, date: decemberMonthDate, calendar: Self.calendar)
        let januaryMonthSpread = DataModel.Spread(period: .month, date: januaryMonthDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2025, month: 12, day: 29),
            endDate: Self.makeDate(year: 2026, month: 1, day: 4),
            calendar: Self.calendar
        )
        let decemberTask = DataModel.Task(
            title: "December-origin",
            date: decemberMonthDate,
            period: .day,
            status: .open,
            assignments: [Assignment(period: .month, date: decemberMonthDate, status: .open)]
        )
        let januaryTask = DataModel.Task(
            title: "January-origin",
            date: januaryMonthDate,
            period: .day,
            status: .open,
            assignments: [Assignment(period: .month, date: januaryMonthDate, status: .open)]
        )

        let legacyPlanner = StandardMigrationPlanner(calendar: Self.calendar)
        let legacyCandidates = legacyPlanner.parentHierarchyMigrationCandidates(
            tasks: [decemberTask, januaryTask],
            spreads: [decemberMonthSpread, januaryMonthSpread, multidaySpread],
            to: multidaySpread
        )

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let engineCandidates = engine.parentHierarchyMigrationCandidates(
            tasks: [decemberTask, januaryTask],
            spreads: [decemberMonthSpread, januaryMonthSpread, multidaySpread],
            to: multidaySpread
        )

        #expect(legacyCandidates.map(\.task.id) == engineCandidates.map(\.entry.id))
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
            assignments: [Assignment(period: .month, date: monthDate, status: .open)]
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
            assignments: [
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
            assignments: [
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

    /// Setup: a mixed set of overdue/not-overdue/Inbox/spread-sourced tasks run through both
    /// the legacy `StandardOverdueEvaluator` (with its separately injected `StandardMigrationPlanner`)
    /// and `JournalRuleEngine` (which reuses its own `currentDestinationSpread` directly).
    /// Expected: identical output, proving the consolidation didn't change behavior despite
    /// removing the separate injected planner dependency.
    @Test func testOverdueTaskItemsMatchesLegacyEvaluator() {
        let today = Self.makeDate(year: 2026, month: 5, day: 3)
        let monthDate = Self.makeDate(year: 2026, month: 4, day: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let spreadSourcedTask = DataModel.Task(
            title: "Spread overdue",
            date: Self.makeDate(year: 2026, month: 5, day: 20),
            period: .day,
            status: .open,
            assignments: [Assignment(period: .month, date: monthDate, status: .open)]
        )
        let inboxTask = DataModel.Task(
            title: "Inbox overdue",
            date: Self.makeDate(year: 2026, month: 4, day: 11),
            period: .day,
            status: .open
        )
        let notOverdueTask = DataModel.Task(
            title: "Not overdue",
            date: Self.makeDate(year: 2026, month: 5, day: 20),
            period: .day,
            status: .open
        )

        let legacyEvaluator = StandardOverdueEvaluator(
            calendar: Self.calendar,
            today: today,
            migrationPlanner: StandardMigrationPlanner(calendar: Self.calendar)
        )
        let legacyItems = legacyEvaluator.overdueTaskItems(
            tasks: [spreadSourcedTask, inboxTask, notOverdueTask],
            spreads: [monthSpread]
        )

        let engine = JournalRuleEngine(calendar: Self.calendar, today: today)
        let engineItems = engine.overdueTaskItems(
            tasks: [spreadSourcedTask, inboxTask, notOverdueTask],
            spreads: [monthSpread]
        )

        #expect(legacyItems.map(\.task.id) == engineItems.map(\.task.id))
        #expect(legacyItems.map(\.sourceKey.id) == engineItems.map(\.sourceKey.id))
    }
}
