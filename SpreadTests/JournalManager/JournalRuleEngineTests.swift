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
}
