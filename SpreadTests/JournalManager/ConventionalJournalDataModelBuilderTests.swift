import Foundation
import Testing
@testable import Spread

struct ConventionalJournalDataModelBuilderTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Setup: a day spread has one directly assigned task and one migrated-history task.
    /// Expected: the conventional builder includes only the current non-migrated assignment.
    @Test func testBuilderExcludesMigratedHistoryFromExplicitSpreadContent() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)

        let openTask = DataModel.Task(
            title: "Open",
            date: dayDate,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )
        let migratedTask = DataModel.Task(
            title: "Migrated",
            date: dayDate,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .migrated)]
        )

        let builder = ConventionalJournalDataModelBuilder(calendar: Self.calendar)
        let model = builder.buildDataModel(
            spreads: [daySpread],
            tasks: [openTask, migratedTask],
            notes: [],
            events: []
        )

        let dayModel = model[.day]?[Period.day.normalizeDate(dayDate, calendar: Self.calendar)]
        #expect(dayModel?.tasks.map(\.id) == [openTask.id])
    }

    /// Setup: a multiday spread spans January 10 through January 12 with entries inside and outside the range.
    /// Expected: only entries whose preferred dates fall within the inclusive range appear on the multiday spread.
    @Test func testBuilderAggregatesOnlyEntriesInsideMultidayRange() {
        let startDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let endDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)

        let inRangeTask = DataModel.Task(title: "In Range", date: Self.makeDate(year: 2026, month: 1, day: 11), period: .day)
        let inRangeNote = DataModel.Note(title: "In Range Note", date: endDate, period: .day)
        let outOfRangeTask = DataModel.Task(title: "Out", date: Self.makeDate(year: 2026, month: 1, day: 13), period: .day)

        let builder = ConventionalJournalDataModelBuilder(calendar: Self.calendar)
        let model = builder.buildDataModel(
            spreads: [multidaySpread],
            tasks: [inRangeTask, outOfRangeTask],
            notes: [inRangeNote],
            events: []
        )

        let spreadModel = model[.multiday]?[multidaySpread.date]
        #expect(spreadModel?.tasks.map(\.id) == [inRangeTask.id])
        #expect(spreadModel?.notes.map(\.id) == [inRangeNote.id])
    }

    /// Setup: a day spread and a multiday spread share a date with overlapping and non-overlapping events.
    /// Expected: the builder uses computed event visibility for both explicit and multiday spreads.
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

        let builder = ConventionalJournalDataModelBuilder(calendar: Self.calendar)
        let model = builder.buildDataModel(
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

    @Test func testBuildSpreadDataModelMatchesFullBuildForExplicitSpread() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Open",
            date: dayDate,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )

        let builder = ConventionalJournalDataModelBuilder(calendar: Self.calendar)
        let fullModel = builder.buildDataModel(
            spreads: [daySpread],
            tasks: [task],
            notes: [],
            events: []
        )
        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let targeted = builder.buildSpreadDataModel(
            for: key,
            spreads: [daySpread],
            tasks: [task],
            notes: [],
            events: []
        )

        #expect(targeted?.spread.id == fullModel[key: key]?.spread.id)
        #expect(targeted?.tasks.map(\.id) == fullModel[key: key]?.tasks.map(\.id))
    }

    /// Setup: a task has a current day assignment, a migrated year-history assignment, and a matching multiday spread.
    /// Expected: targeted rebuild keys include only the live explicit assignment plus matching multiday aggregation.
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
            period: .day,
            assignments: [
                TaskAssignment(period: .year, date: taskDate, status: .migrated),
                TaskAssignment(period: .day, date: taskDate, status: .open)
            ]
        )

        let builder = ConventionalJournalDataModelBuilder(calendar: Self.calendar)
        let keys = builder.spreadKeys(for: task, spreads: [daySpread, multidaySpread])

        #expect(keys.count == 2)
        #expect(keys.contains(SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)))
        #expect(keys.contains(SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)))
        #expect(!keys.contains(SpreadDataModelKey(period: .year, date: taskDate, calendar: Self.calendar)))
    }
}
