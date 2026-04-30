import Foundation
import Testing
@testable import Spread

/// Tests verifying multiday spread UI behavior.
///
/// Validates:
/// - Range header formatting for multiday spreads
/// - Entry aggregation by date range (not assignment)
/// - Grouping entries by day within the range
/// - Migration banner exclusion (multiday doesn't own entries)
@Suite("Multiday Spread UI Tests")
struct MultidaySpreadUITests {

    // MARK: - Test Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeMultidaySpread(
        startYear: Int, startMonth: Int, startDay: Int,
        endYear: Int, endMonth: Int, endDay: Int
    ) -> DataModel.Spread {
        let startDate = makeDate(year: startYear, month: startMonth, day: startDay)
        let endDate = makeDate(year: endYear, month: endMonth, day: endDay)
        return DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
    }

    // MARK: - Range Header Tests

    /// Conditions: Multiday spread within a single month (Jan 6-12, 2026).
    /// Expected: Header title shows "6 Jan - 12 Jan".
    @Test("Multiday header shows same-year range")
    func multidayHeaderShowsSameYearRange() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )
        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "6 Jan - 12 Jan")
    }

    /// Conditions: Multiday spread crossing year boundary (Dec 28, 2025 - Jan 3, 2026).
    /// Expected: Header title shows "28 Dec - 3 Jan".
    @Test("Multiday header shows cross-year range")
    func multidayHeaderShowsCrossYearRange() {
        let spread = makeMultidaySpread(
            startYear: 2025, startMonth: 12, startDay: 28,
            endYear: 2026, endMonth: 1, endDay: 3
        )
        let config = SpreadHeaderConfiguration(spread: spread, calendar: calendar)

        #expect(config.title == "28 Dec - 3 Jan")
    }

    // MARK: - Display Label Tests

    /// Conditions: Multiday spread within a single month.
    /// Expected: Display label shows compact format (e.g., "6-12").
    @Test("Multiday display label shows compact same-month range")
    func multidayDisplayLabelShowsCompactSameMonthRange() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )

        #expect(spread.displayLabel(calendar: calendar) == "6-12")
    }

    /// Conditions: Multiday spread crossing months.
    /// Expected: Display label shows month abbreviations (e.g., "Jan 28-Feb 3").
    @Test("Multiday display label shows cross-month range")
    func multidayDisplayLabelShowsCrossMonthRange() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 28,
            endYear: 2026, endMonth: 2, endDay: 3
        )

        #expect(spread.displayLabel(calendar: calendar) == "Jan 28-Feb 3")
    }

    // MARK: - Entry Aggregation Tests

    /// Conditions: Multiday spread with entries from multiple days within range.
    /// Expected: Entries are grouped by day with one section per covered date.
    @Test("Multiday entries grouped by day within range")
    func multidayEntriesGroupedByDay() {
        let spreadDate = makeDate(year: 2026, month: 1, day: 6)
        let endDate = makeDate(year: 2026, month: 1, day: 8)
        let grouper = EntryListGrouper(
            period: .multiday,
            spreadDate: spreadDate,
            spreadStartDate: spreadDate,
            spreadEndDate: endDate,
            calendar: calendar
        )

        let entries: [any Entry] = [
            DataModel.Task(title: "Day 6 task", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 7 task", date: makeDate(year: 2026, month: 1, day: 7)),
            DataModel.Note(title: "Day 6 note", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 8 task", date: makeDate(year: 2026, month: 1, day: 8))
        ]

        let sections = grouper.group(entries)

        #expect(sections.count == 3)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.count == 2) // task + note
        #expect(sections[1].title.isEmpty)
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].title.isEmpty)
        #expect(sections[2].entries.count == 1)
    }

    /// Conditions: Multiday spread with no entries.
    /// Expected: Grouper returns empty sections.
    @Test("Multiday with no entries returns empty sections")
    func multidayNoEntriesReturnsEmpty() {
        let spreadDate = makeDate(year: 2026, month: 1, day: 6)
        let endDate = makeDate(year: 2026, month: 1, day: 8)
        let grouper = EntryListGrouper(
            period: .multiday,
            spreadDate: spreadDate,
            spreadStartDate: spreadDate,
            spreadEndDate: endDate,
            calendar: calendar
        )

        let sections = grouper.group([])

        #expect(sections.count == 3)
        #expect(sections.allSatisfy { $0.title.isEmpty })
        #expect(sections.allSatisfy { $0.entries.isEmpty })
    }

    // MARK: - Day Card State Tests

    @Test("Multiday day card uses created state when explicit day exists")
    func multidayDayCardUsesCreatedStateForExplicitDay() {
        let date = makeDate(year: 2026, month: 1, day: 10)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let state = MultidayDayCardSupport.visualState(
            for: date,
            today: makeDate(year: 2026, month: 1, day: 12),
            explicitDaySpread: daySpread,
            calendar: calendar
        )

        #expect(state == .created)
    }

    @Test("Multiday day card uses uncreated state when explicit day is missing")
    func multidayDayCardUsesUncreatedStateWhenDayMissing() {
        let date = makeDate(year: 2026, month: 1, day: 10)

        let state = MultidayDayCardSupport.visualState(
            for: date,
            today: makeDate(year: 2026, month: 1, day: 12),
            explicitDaySpread: nil,
            calendar: calendar
        )

        #expect(state == .uncreated)
    }

    @Test("Multiday day card uses today uncreated state when explicit day is missing")
    func multidayDayCardTodayWithoutDaySpreadKeepsDashedState() {
        let date = makeDate(year: 2026, month: 1, day: 10)

        let state = MultidayDayCardSupport.visualState(
            for: date,
            today: date,
            explicitDaySpread: nil,
            calendar: calendar
        )

        #expect(state == .todayUncreated)
    }

    @Test("Multiday day card uses today created state when explicit day exists")
    func multidayDayCardTodayWithDaySpreadUsesCreatedTodayState() {
        let date = makeDate(year: 2026, month: 1, day: 10)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let state = MultidayDayCardSupport.visualState(
            for: date,
            today: date,
            explicitDaySpread: daySpread,
            calendar: calendar
        )

        #expect(state == .todayCreated)
    }

    @Test("Multiday footer action navigates when explicit day exists")
    func multidayFooterActionNavigatesForExistingDay() {
        let date = makeDate(year: 2026, month: 1, day: 10)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let action = MultidayDayCardSupport.footerAction(
            for: date,
            explicitDaySpread: daySpread
        )

        #expect(action == .navigate(daySpread))
        #expect(action.iconName == "arrow.right")
    }

    @Test("Multiday footer action creates prefills when explicit day is missing")
    func multidayFooterActionCreatesForMissingDay() {
        let date = makeDate(year: 2026, month: 1, day: 10)

        let action = MultidayDayCardSupport.footerAction(
            for: date,
            explicitDaySpread: nil
        )

        #expect(action == .createDay(date))
        #expect(action.iconName == "calendar.badge.plus")
    }

    // MARK: - No Migration Banner Tests

    /// Conditions: Multiday period.
    /// Expected: canHaveTasksAssigned is false, preventing migration to multiday.
    @Test("Multiday period cannot have tasks assigned")
    func multidayCannotHaveTasksAssigned() {
        #expect(Period.multiday.canHaveTasksAssigned == false)
    }

    /// Conditions: SpreadDataModel with multiday spread and aggregated entries.
    /// Expected: Entry counts reflect aggregated (not assigned) entries.
    @Test("Multiday SpreadDataModel reflects aggregated entry counts")
    func multidayDataModelReflectsAggregatedCounts() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )
        let tasks = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 1, day: 8))
        ]
        let notes = [
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 1, day: 7))
        ]

        let dataModel = SpreadDataModel(
            spread: spread,
            tasks: tasks,
            notes: notes,
            events: []
        )
        let config = SpreadHeaderConfiguration(spreadDataModel: dataModel, calendar: calendar)

        #expect(config.taskCount == 2)
        #expect(config.noteCount == 1)
        #expect(config.countSummaryText == "2 tasks, 1 note")
    }

    // MARK: - Hierarchy Organization Tests

    /// Conditions: Multiday spread in the hierarchy organizer.
    /// Expected: Multiday spread appears under the correct month at the day level.
    @Test("Multiday spread appears in hierarchy under correct month")
    func multidayAppearsInHierarchy() {
        let yearDate = makeDate(year: 2026, month: 1, day: 1)
        let monthDate = makeDate(year: 2026, month: 1, day: 1)
        let multidaySpread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )

        let spreads = [
            DataModel.Spread(period: .year, date: yearDate, calendar: calendar),
            DataModel.Spread(period: .month, date: monthDate, calendar: calendar),
            multidaySpread
        ]

        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        #expect(organizer.years.count == 1)
        #expect(organizer.years[0].months.count == 1)
        #expect(organizer.years[0].months[0].days.count == 1)
        #expect(organizer.years[0].months[0].days[0].spread.period == .multiday)
    }

    /// Conditions: Multiday spread alongside day spreads in the same month.
    /// Expected: Both appear in the hierarchy, sorted chronologically.
    @Test("Multiday spread sorted with day spreads in hierarchy")
    func multidaySortedWithDaySpreads() {
        let yearDate = makeDate(year: 2026, month: 1, day: 1)
        let monthDate = makeDate(year: 2026, month: 1, day: 1)
        let daySpread = DataModel.Spread(
            period: .day,
            date: makeDate(year: 2026, month: 1, day: 5),
            calendar: calendar
        )
        let multidaySpread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )
        let daySpread2 = DataModel.Spread(
            period: .day,
            date: makeDate(year: 2026, month: 1, day: 15),
            calendar: calendar
        )

        let spreads = [
            DataModel.Spread(period: .year, date: yearDate, calendar: calendar),
            DataModel.Spread(period: .month, date: monthDate, calendar: calendar),
            daySpread,
            multidaySpread,
            daySpread2
        ]

        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)
        let days = organizer.years[0].months[0].days

        #expect(days.count == 3)
        #expect(days[0].spread.period == .day)
        #expect(days[1].spread.period == .multiday)
        #expect(days[2].spread.period == .day)
    }

    // MARK: - Date Containment Tests

    /// Conditions: A date within the multiday range.
    /// Expected: contains(date:calendar:) returns true.
    @Test("Multiday spread contains date within range")
    func multidayContainsDateWithinRange() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )
        let dateInRange = makeDate(year: 2026, month: 1, day: 9)

        #expect(spread.contains(date: dateInRange, calendar: calendar))
    }

    /// Conditions: A date outside the multiday range.
    /// Expected: contains(date:calendar:) returns false.
    @Test("Multiday spread excludes date outside range")
    func multidayExcludesDateOutsideRange() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )
        let dateOutside = makeDate(year: 2026, month: 1, day: 13)

        #expect(!spread.contains(date: dateOutside, calendar: calendar))
    }

    /// Conditions: The start and end dates of the multiday range.
    /// Expected: Both boundary dates are contained (inclusive).
    @Test("Multiday spread range is inclusive of boundaries")
    func multidayRangeIsInclusive() {
        let spread = makeMultidaySpread(
            startYear: 2026, startMonth: 1, startDay: 6,
            endYear: 2026, endMonth: 1, endDay: 12
        )
        let startDate = makeDate(year: 2026, month: 1, day: 6)
        let endDate = makeDate(year: 2026, month: 1, day: 12)

        #expect(spread.contains(date: startDate, calendar: calendar))
        #expect(spread.contains(date: endDate, calendar: calendar))
    }
}
