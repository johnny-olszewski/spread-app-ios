import Foundation
import Testing
@testable import Spread

/// Tests for spread header formatting and display logic.
///
/// Verifies:
/// - Title formatting for each period type (year, month, day, multiday)
/// - Entry counts display correctly
/// - Multiday date range formatting across months/years
@Suite("Spread Header Tests")
struct SpreadHeaderTests {

    // MARK: - Test Fixtures

    private func makeTestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }

    // MARK: - Year Title Formatting Tests

    /// Conditions: Year spread for 2026.
    /// Expected: Title displays "2026".
    @Test("Year spread title displays year number")
    func yearSpreadTitleDisplaysYearNumber() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let spread = DataModel.Spread(period: .year, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "2026")
    }

    /// Conditions: Year spread for different years.
    /// Expected: Title displays the correct year number for each.
    @Test("Year spread title works for various years")
    func yearSpreadTitleWorksForVariousYears() {
        let calendar = makeTestCalendar()

        let years = [2024, 2025, 2027, 2030]
        for year in years {
            let date = makeDate(year: year, month: 6, day: 15, calendar: calendar)
            let spread = DataModel.Spread(period: .year, date: date, calendar: calendar)
            let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

            #expect(config.title == "\(year)")
        }
    }

    // MARK: - Month Title Formatting Tests

    /// Conditions: Month spread for January 2026.
    /// Expected: Title displays "January 2026".
    @Test("Month spread title displays month and year")
    func monthSpreadTitleDisplaysMonthAndYear() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let spread = DataModel.Spread(period: .month, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "January 2026")
    }

    /// Conditions: Month spreads for various months.
    /// Expected: Title displays full month name and year for each.
    @Test("Month spread title works for various months")
    func monthSpreadTitleWorksForVariousMonths() {
        let calendar = makeTestCalendar()
        let expectedTitles = [
            (1, "January 2026"),
            (2, "February 2026"),
            (6, "June 2026"),
            (12, "December 2026")
        ]

        for (month, expected) in expectedTitles {
            let date = makeDate(year: 2026, month: month, day: 15, calendar: calendar)
            let spread = DataModel.Spread(period: .month, date: date, calendar: calendar)
            let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

            #expect(config.title == expected)
        }
    }

    // MARK: - Day Title Formatting Tests

    /// Conditions: Day spread for January 5, 2026.
    /// Expected: Title displays full date format (e.g., "January 5, 2026").
    @Test("Day spread title displays full date")
    func daySpreadTitleDisplaysFullDate() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 5, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "January 5, 2026")
    }

    /// Conditions: Day spreads for various dates.
    /// Expected: Title displays the full date format for each.
    @Test("Day spread title works for various dates")
    func daySpreadTitleWorksForVariousDates() {
        let calendar = makeTestCalendar()
        let expectedTitles = [
            (2026, 1, 1, "January 1, 2026"),
            (2026, 12, 31, "December 31, 2026"),
            (2026, 2, 14, "February 14, 2026"),
            (2026, 7, 4, "July 4, 2026")
        ]

        for (year, month, day, expected) in expectedTitles {
            let date = makeDate(year: year, month: month, day: day, calendar: calendar)
            let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)
            let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

            #expect(config.title == expected)
        }
    }

    // MARK: - Multiday Title Formatting Tests

    /// Conditions: Multiday spread within same month (Jan 6-12, 2026).
    /// Expected: Title displays "Jan 6 - Jan 12, 2026".
    @Test("Multiday spread title displays date range within same month")
    func multidaySpreadTitleDisplaysDateRangeWithinMonth() {
        let calendar = makeTestCalendar()
        let startDate = makeDate(year: 2026, month: 1, day: 6, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 1, day: 12, calendar: calendar)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "Jan 6 - Jan 12, 2026")
    }

    /// Conditions: Multiday spread spanning two months (Jan 28 - Feb 3, 2026).
    /// Expected: Title displays "Jan 28 - Feb 3, 2026".
    @Test("Multiday spread title displays date range spanning months")
    func multidaySpreadTitleDisplaysDateRangeSpanningMonths() {
        let calendar = makeTestCalendar()
        let startDate = makeDate(year: 2026, month: 1, day: 28, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 2, day: 3, calendar: calendar)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "Jan 28 - Feb 3, 2026")
    }

    /// Conditions: Multiday spread spanning two years (Dec 28, 2025 - Jan 3, 2026).
    /// Expected: Title displays "Dec 28, 2025 - Jan 3, 2026".
    @Test("Multiday spread title displays date range spanning years")
    func multidaySpreadTitleDisplaysDateRangeSpanningYears() {
        let calendar = makeTestCalendar()
        let startDate = makeDate(year: 2025, month: 12, day: 28, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 1, day: 3, calendar: calendar)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "Dec 28, 2025 - Jan 3, 2026")
    }

    /// Conditions: Multiday spread with missing dates (edge case).
    /// Expected: Title displays "Multiday" as fallback.
    @Test("Multiday spread title shows fallback when dates missing")
    func multidaySpreadTitleShowsFallbackWhenDatesMissing() {
        let calendar = makeTestCalendar()
        // Create a multiday spread but manually set dates to nil (edge case)
        let date = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let spread = DataModel.Spread(period: .multiday, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "Multiday")
    }

    // MARK: - Entry Counts Tests

    /// Conditions: Spread with zero entries.
    /// Expected: All counts are zero.
    @Test("Entry counts are zero when no entries")
    func entryCountsZeroWhenNoEntries() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 0,
            eventCount: 0,
            noteCount: 0
        )

        #expect(config.taskCount == 0)
        #expect(config.eventCount == 0)
        #expect(config.noteCount == 0)
        #expect(config.totalCount == 0)
    }

    /// Conditions: Spread with tasks only.
    /// Expected: Task count reflects count, others are zero.
    @Test("Entry counts reflect tasks only")
    func entryCountsReflectTasksOnly() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 5,
            eventCount: 0,
            noteCount: 0
        )

        #expect(config.taskCount == 5)
        #expect(config.eventCount == 0)
        #expect(config.noteCount == 0)
        #expect(config.totalCount == 5)
    }

    /// Conditions: Spread with events only.
    /// Expected: Event count reflects count, total excludes events (v1).
    @Test("Entry counts ignore events for totals")
    func entryCountsIgnoreEventsForTotals() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 0,
            eventCount: 3,
            noteCount: 0
        )

        #expect(config.taskCount == 0)
        #expect(config.eventCount == 3)
        #expect(config.noteCount == 0)
        #expect(config.totalCount == 0)
    }

    /// Conditions: Spread with notes only.
    /// Expected: Note count reflects count, others are zero.
    @Test("Entry counts reflect notes only")
    func entryCountsReflectNotesOnly() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 0,
            eventCount: 0,
            noteCount: 2
        )

        #expect(config.taskCount == 0)
        #expect(config.eventCount == 0)
        #expect(config.noteCount == 2)
        #expect(config.totalCount == 2)
    }

    /// Conditions: Spread with mixed entries.
    /// Expected: Total excludes events (v1).
    @Test("Entry counts reflect mixed entries")
    func entryCountsReflectMixedEntries() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 5,
            eventCount: 3,
            noteCount: 2
        )

        #expect(config.taskCount == 5)
        #expect(config.eventCount == 3)
        #expect(config.noteCount == 2)
        #expect(config.totalCount == 7)
    }

    // MARK: - Count Summary Text Tests

    /// Conditions: Spread with zero entries.
    /// Expected: Summary text indicates no entries.
    @Test("Count summary text shows no entries message")
    func countSummaryTextShowsNoEntriesMessage() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 0,
            eventCount: 0,
            noteCount: 0
        )

        #expect(config.countSummaryText == "No entries")
    }

    /// Conditions: Spread with one task only.
    /// Expected: Summary text shows singular "1 task".
    @Test("Count summary text shows singular task")
    func countSummaryTextShowsSingularTask() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 1,
            eventCount: 0,
            noteCount: 0
        )

        #expect(config.countSummaryText == "1 task")
    }

    /// Conditions: Spread with multiple tasks only.
    /// Expected: Summary text shows plural "5 tasks".
    @Test("Count summary text shows plural tasks")
    func countSummaryTextShowsPluralTasks() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 5,
            eventCount: 0,
            noteCount: 0
        )

        #expect(config.countSummaryText == "5 tasks")
    }

    /// Conditions: Spread with tasks and events.
    /// Expected: Summary text ignores events (v1).
    @Test("Count summary text ignores events")
    func countSummaryTextIgnoresEvents() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 3,
            eventCount: 2,
            noteCount: 0
        )

        #expect(config.countSummaryText == "3 tasks")
    }

    /// Conditions: Spread with all entry types.
    /// Expected: Summary text excludes events (v1).
    @Test("Count summary text excludes events")
    func countSummaryTextExcludesEvents() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 3,
            eventCount: 2,
            noteCount: 1
        )

        #expect(config.countSummaryText == "3 tasks, 1 note")
    }

    /// Conditions: Spread with one of each entry type.
    /// Expected: Summary text uses singular forms and ignores events (v1).
    @Test("Count summary text uses singular forms correctly")
    func countSummaryTextUsesSingularFormsCorrectly() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            taskCount: 1,
            eventCount: 1,
            noteCount: 1
        )

        #expect(config.countSummaryText == "1 task, 1 note")
    }

    // MARK: - SpreadDataModel Integration Tests

    /// Conditions: SpreadDataModel with entries.
    /// Expected: Configuration extracts counts; total excludes events (v1).
    @Test("Configuration extracts counts from SpreadDataModel")
    func configurationExtractsCountsFromSpreadDataModel() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let tasks = [
            DataModel.Task(title: "Task 1"),
            DataModel.Task(title: "Task 2")
        ]
        let events = [
            DataModel.Event(title: "Event 1")
        ]
        let notes = [
            DataModel.Note(title: "Note 1"),
            DataModel.Note(title: "Note 2"),
            DataModel.Note(title: "Note 3")
        ]

        let spreadDataModel = SpreadDataModel(
            spread: spread,
            tasks: tasks,
            notes: notes,
            events: events
        )

        let config = SpreadHeaderConfiguration(spreadDataModel: spreadDataModel, calendar: calendar)

        #expect(config.taskCount == 2)
        #expect(config.eventCount == 1)
        #expect(config.noteCount == 3)
        #expect(config.totalCount == 5)
    }
}
