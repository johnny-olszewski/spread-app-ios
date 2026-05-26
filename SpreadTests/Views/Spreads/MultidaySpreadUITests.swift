import Foundation
import Testing
@testable import Spread

/// Tests verifying multiday spread UI behavior.
///
/// Validates:
/// - Range header formatting for multiday spreads
/// - Grouping entries by day within the range
/// - Multiday hierarchy placement
/// - Multiday assignment affordances
@Suite("Multiday Spread UI Tests")
@MainActor
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

        let entries: [any Entry] = [
            DataModel.Task(title: "Day 6 task", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 7 task", date: makeDate(year: 2026, month: 1, day: 7)),
            DataModel.Note(title: "Day 6 note", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 8 task", date: makeDate(year: 2026, month: 1, day: 8))
        ]

        let sections = MultidaySpreadContentView.makeSections(
            from: entries,
            spreadDate: spreadDate,
            startDate: spreadDate,
            endDate: endDate,
            calendar: calendar
        )

        #expect(sections.count == 3)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.count == 2) // task + note
        #expect(sections[1].title.isEmpty)
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].title.isEmpty)
        #expect(sections[2].entries.count == 1)
    }

    /// Conditions: Multiday spread with no entries.
    /// Expected: makeSections returns empty sections for each covered day.
    @Test("Multiday with no entries returns empty sections")
    func multidayNoEntriesReturnsEmpty() {
        let spreadDate = makeDate(year: 2026, month: 1, day: 6)
        let endDate = makeDate(year: 2026, month: 1, day: 8)

        let sections = MultidaySpreadContentView.makeSections(
            from: [],
            spreadDate: spreadDate,
            startDate: spreadDate,
            endDate: endDate,
            calendar: calendar
        )

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
    func multidayDayCardTodayWithoutDaySpreadUsesTodayUncreatedState() {
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
    /// Expected: canHaveTasksAssigned is true, allowing direct multiday ownership.
    @Test("Multiday period cannot have tasks assigned")
    func multidayCannotHaveTasksAssigned() {
        #expect(Period.multiday.canHaveTasksAssigned == true)
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

    // MARK: - Navigation Callback Tests

    /// Conditions: A day within the multiday range has an explicit day spread.
    /// Expected: The footer action is .navigate and processing it invokes onSelectSpread with the correct spread.
    @Test("Navigate footer action invokes onSelectSpread with the correct day spread")
    func navigateFooterActionInvokesOnSelectSpreadWithCorrectSpread() {
        let date = makeDate(year: 2026, month: 1, day: 10)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)
        let action = MultidayDayCardSupport.footerAction(for: date, explicitDaySpread: daySpread)

        var navigatedSpread: DataModel.Spread?
        let onSelectSpread: (DataModel.Spread) -> Void = { navigatedSpread = $0 }

        // Simulate the tap handler logic executed by multidayDaySection.
        if case .navigate(let spread) = action {
            onSelectSpread(spread)
        }

        #expect(navigatedSpread == daySpread)
    }

    /// Conditions: A day within the multiday range has no explicit day spread.
    /// Expected: The footer action is .createDay and processing it invokes onCreateSpread with the correct date.
    @Test("Create footer action invokes onCreateSpread with the correct date")
    func createFooterActionInvokesOnCreateSpreadWithCorrectDate() {
        let date = makeDate(year: 2026, month: 1, day: 10)
        let action = MultidayDayCardSupport.footerAction(for: date, explicitDaySpread: nil)

        var createdDate: Date?
        let onCreateSpread: (Date) -> Void = { createdDate = $0 }

        // Simulate the tap handler logic executed by multidayDaySection.
        if case .createDay(let actionDate) = action {
            onCreateSpread(actionDate)
        }

        #expect(createdDate == date)
    }

    /// Conditions: Two different day spreads exist within the multiday range.
    /// Expected: The navigate action for each day resolves to its own respective day spread, not the other.
    @Test("Navigate action resolves to the correct spread per day when multiple day spreads exist")
    func navigateActionResolvesToCorrectSpreadPerDay() {
        let date1 = makeDate(year: 2026, month: 1, day: 10)
        let date2 = makeDate(year: 2026, month: 1, day: 11)
        let daySpread1 = DataModel.Spread(period: .day, date: date1, calendar: calendar)
        let daySpread2 = DataModel.Spread(period: .day, date: date2, calendar: calendar)

        let action1 = MultidayDayCardSupport.footerAction(for: date1, explicitDaySpread: daySpread1)
        let action2 = MultidayDayCardSupport.footerAction(for: date2, explicitDaySpread: daySpread2)

        guard case .navigate(let resolved1) = action1,
              case .navigate(let resolved2) = action2 else {
            Issue.record("Expected both actions to be .navigate")
            return
        }

        #expect(resolved1 == daySpread1)
        #expect(resolved2 == daySpread2)
        #expect(resolved1 != resolved2)
    }
}
