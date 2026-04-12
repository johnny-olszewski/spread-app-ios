import Foundation
import Testing
@testable import Spread

struct TraditionalJournalDataModelBuilderTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Setup: tasks and notes span one year preference, one explicit month preference, and one day preference.
    /// Expected: the traditional builder generates the virtual spreads needed for exact preferred periods plus any parent periods needed to surface those dates.
    @Test func testBuilderCreatesOnlyNeededTraditionalVirtualSpreads() {
        let yearTask = DataModel.Task(title: "Year", date: Self.makeDate(year: 2026, month: 1), period: .year)
        let monthTask = DataModel.Task(title: "Month", date: Self.makeDate(year: 2026, month: 4, day: 20), period: .month)
        let dayNote = DataModel.Note(title: "Day", date: Self.makeDate(year: 2026, month: 4, day: 6), period: .day)

        let builder = TraditionalJournalDataModelBuilder(calendar: Self.calendar)
        let model = builder.buildDataModel(
            spreads: [],
            tasks: [yearTask, monthTask],
            notes: [dayNote],
            events: []
        )

        #expect(model[.year]?.count == 1)
        #expect(model[.month]?.count == 2)
        #expect(model[.day]?.count == 1)
        #expect(model[.multiday] == nil)
    }

    /// Setup: a month-level task and a day-level task share April 2026.
    /// Expected: traditional month includes only the month-level task while the day-level task appears only on its exact day spread.
    @Test func testBuilderKeepsMonthAndDayEntriesOnTheirExactPreferredPeriods() {
        let monthDate = Self.makeDate(year: 2026, month: 4)
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let monthTask = DataModel.Task(title: "Month", date: monthDate, period: .month)
        let dayTask = DataModel.Task(title: "Day", date: dayDate, period: .day)

        let builder = TraditionalJournalDataModelBuilder(calendar: Self.calendar)
        let model = builder.buildDataModel(
            spreads: [],
            tasks: [monthTask, dayTask],
            notes: [],
            events: []
        )

        let monthModel = model[.month]?[Period.month.normalizeDate(monthDate, calendar: Self.calendar)]
        let dayModel = model[.day]?[Period.day.normalizeDate(dayDate, calendar: Self.calendar)]
        #expect(monthModel?.tasks.map(\.id) == [monthTask.id])
        #expect(dayModel?.tasks.map(\.id) == [dayTask.id])
    }

    /// Setup: one event overlaps a requested day spread and another belongs to a different day.
    /// Expected: traditional virtual spread generation still uses computed event visibility for matching days.
    @Test func testBuilderUsesComputedEventVisibilityOnTraditionalVirtualSpreads() {
        let dayDate = Self.makeDate(year: 2026, month: 5, day: 3)
        let matchingEvent = DataModel.Event(title: "Match", startDate: dayDate, endDate: dayDate)
        let otherEvent = DataModel.Event(
            title: "Other",
            startDate: Self.makeDate(year: 2026, month: 5, day: 4),
            endDate: Self.makeDate(year: 2026, month: 5, day: 4)
        )

        let builder = TraditionalJournalDataModelBuilder(calendar: Self.calendar)
        let model = builder.buildDataModel(
            spreads: [],
            tasks: [],
            notes: [],
            events: [matchingEvent, otherEvent]
        )

        let dayModel = model[.day]?[Period.day.normalizeDate(dayDate, calendar: Self.calendar)]
        #expect(dayModel?.events.map(\.id) == [matchingEvent.id])
    }
}
