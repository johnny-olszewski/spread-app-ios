import Testing
import struct Foundation.Calendar
import struct Foundation.Date
@testable import Spread

/// Tests for spread hierarchy organization and selection logic.
///
/// Verifies:
/// - Spreads are organized by hierarchy (year → month → day + multiday)
/// - Chronological ordering within each level
/// - Initial selection defaults to smallest period containing today
/// - Multiday tiebreaker: earliest start, then end, then creation date
@Suite("Spread Hierarchy Tests")
struct SpreadHierarchyTests {

    // MARK: - Test Fixtures

    private func makeTestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }

    // MARK: - Hierarchy Organization Tests

    /// Conditions: Multiple spreads of different periods exist.
    /// Expected: Year spreads group months, months group days + multiday.
    @Test("Spreads organize into year -> month -> day hierarchy")
    func spreadsOrganizeIntoHierarchy() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: today, calendar: calendar),
            DataModel.Spread(period: .month, date: today, calendar: calendar),
            DataModel.Spread(period: .day, date: today, calendar: calendar)
        ]

        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)
        let years = organizer.years

        #expect(years.count == 1)
        #expect(years[0].months.count == 1)
        #expect(years[0].months[0].days.count == 1)
    }

    /// Conditions: Multiple years exist with spreads.
    /// Expected: Years are sorted chronologically (ascending by date).
    @Test("Years are sorted chronologically")
    func yearsAreSortedChronologically() {
        let calendar = makeTestCalendar()
        let date2025 = makeDate(year: 2025, month: 6, day: 1, calendar: calendar)
        let date2026 = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let date2027 = makeDate(year: 2027, month: 3, day: 1, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: date2027, calendar: calendar),
            DataModel.Spread(period: .year, date: date2025, calendar: calendar),
            DataModel.Spread(period: .year, date: date2026, calendar: calendar)
        ]

        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)
        let years = organizer.years

        #expect(years.count == 3)
        #expect(calendar.component(.year, from: years[0].spread.date) == 2025)
        #expect(calendar.component(.year, from: years[1].spread.date) == 2026)
        #expect(calendar.component(.year, from: years[2].spread.date) == 2027)
    }

    /// Conditions: Multiple months exist within a year.
    /// Expected: Months are sorted chronologically within the year.
    @Test("Months are sorted chronologically within year")
    func monthsAreSortedChronologically() {
        let calendar = makeTestCalendar()
        let jan = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let mar = makeDate(year: 2026, month: 3, day: 1, calendar: calendar)
        let feb = makeDate(year: 2026, month: 2, day: 1, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: jan, calendar: calendar),
            DataModel.Spread(period: .month, date: mar, calendar: calendar),
            DataModel.Spread(period: .month, date: jan, calendar: calendar),
            DataModel.Spread(period: .month, date: feb, calendar: calendar)
        ]

        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)
        let months = organizer.years[0].months

        #expect(months.count == 3)
        #expect(calendar.component(.month, from: months[0].spread.date) == 1)
        #expect(calendar.component(.month, from: months[1].spread.date) == 2)
        #expect(calendar.component(.month, from: months[2].spread.date) == 3)
    }

    /// Conditions: Multiple days and multiday spreads exist within a month.
    /// Expected: Days and multiday are sorted by start date (mixed together).
    @Test("Days and multiday spreads are sorted by start date")
    func daysAndMultidaySortedByStartDate() {
        let calendar = makeTestCalendar()
        let jan1 = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let jan5 = makeDate(year: 2026, month: 1, day: 5, calendar: calendar)
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan15 = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: jan1, calendar: calendar),
            DataModel.Spread(period: .month, date: jan1, calendar: calendar),
            DataModel.Spread(period: .day, date: jan15, calendar: calendar),
            DataModel.Spread(period: .day, date: jan5, calendar: calendar),
            DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar) // multiday
        ]

        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)
        let days = organizer.years[0].months[0].days

        #expect(days.count == 3)
        // Jan 5 day, Jan 10-20 multiday, Jan 15 day (sorted by start date)
        #expect(calendar.component(.day, from: days[0].spread.date) == 5)
        #expect(days[1].spread.period == .multiday)
        #expect(calendar.component(.day, from: days[2].spread.date) == 15)
    }

    // MARK: - Initial Selection Tests

    /// Conditions: Day spread exists for today.
    /// Expected: Day spread is selected initially (smallest period).
    @Test("Initial selection prefers day spread containing today")
    func initialSelectionPrefersDaySpread() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let spreads = [yearSpread, monthSpread, daySpread]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == daySpread.id)
    }

    /// Conditions: No day spread exists, but month spread exists for today.
    /// Expected: Month spread is selected initially.
    @Test("Initial selection falls back to month spread")
    func initialSelectionFallsBackToMonth() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)

        let spreads = [yearSpread, monthSpread]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == monthSpread.id)
    }

    /// Conditions: No day or month spread exists, but year spread exists.
    /// Expected: Year spread is selected initially.
    @Test("Initial selection falls back to year spread")
    func initialSelectionFallsBackToYear() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let spreads = [yearSpread]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == yearSpread.id)
    }

    /// Conditions: Day spread exists for today and multiday spread includes today.
    /// Expected: Day spread is preferred over multiday.
    @Test("Initial selection prefers day over multiday containing today")
    func initialSelectionPrefersDayOverMultiday() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let multidaySpread = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar)

        let spreads = [yearSpread, monthSpread, daySpread, multidaySpread]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == daySpread.id)
    }

    /// Conditions: No day spread exists, multiday spread includes today.
    /// Expected: Multiday spread is selected.
    @Test("Initial selection uses multiday when no day spread exists")
    func initialSelectionUsesMultidayWhenNoDaySpread() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let multidaySpread = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar)

        let spreads = [yearSpread, monthSpread, multidaySpread]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == multidaySpread.id)
    }

    // MARK: - Multiday Tiebreaker Tests

    /// Conditions: Multiple multiday spreads include today with different start dates.
    /// Expected: Multiday with earliest start date is selected.
    @Test("Multiday tiebreaker prefers earliest start date")
    func multidayTiebreakerPrefersEarliestStart() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan12 = makeDate(year: 2026, month: 1, day: 12, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let multiday1 = DataModel.Spread(startDate: jan12, endDate: jan20, calendar: calendar)
        let multiday2 = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar)

        let spreads = [yearSpread, monthSpread, multiday1, multiday2]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == multiday2.id) // jan10 start is earlier
    }

    /// Conditions: Multiple multiday spreads with same start date, different end dates.
    /// Expected: Multiday with earliest end date is selected.
    @Test("Multiday tiebreaker prefers earliest end date when start dates match")
    func multidayTiebreakerPrefersEarliestEnd() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan18 = makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        let jan25 = makeDate(year: 2026, month: 1, day: 25, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let multiday1 = DataModel.Spread(startDate: jan10, endDate: jan25, calendar: calendar)
        let multiday2 = DataModel.Spread(startDate: jan10, endDate: jan18, calendar: calendar)

        let spreads = [yearSpread, monthSpread, multiday1, multiday2]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == multiday2.id) // jan18 end is earlier
    }

    /// Conditions: Multiple multiday spreads with same start and end dates, different creation dates.
    /// Expected: Multiday with earliest creation date is selected.
    @Test("Multiday tiebreaker prefers earliest creation date when ranges match")
    func multidayTiebreakerPrefersEarliestCreation() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)
        let created1 = makeDate(year: 2026, month: 1, day: 5, calendar: calendar)
        let created2 = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let multiday1 = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar, createdDate: created1)
        let multiday2 = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar, createdDate: created2)

        let spreads = [yearSpread, monthSpread, multiday1, multiday2]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection?.id == multiday2.id) // jan1 creation is earlier
    }

    // MARK: - Empty State Tests

    /// Conditions: No spreads exist.
    /// Expected: Initial selection is nil.
    @Test("Initial selection is nil when no spreads exist")
    func initialSelectionNilWhenNoSpreads() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let organizer = SpreadHierarchyOrganizer(spreads: [], calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection == nil)
    }

    /// Conditions: No spreads contain today.
    /// Expected: Initial selection is nil.
    @Test("Initial selection is nil when no spreads contain today")
    func initialSelectionNilWhenNoSpreadsContainToday() {
        let calendar = makeTestCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let futureDate = makeDate(year: 2027, month: 6, day: 1, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: futureDate, calendar: calendar)
        let spreads = [yearSpread]
        let organizer = SpreadHierarchyOrganizer(spreads: spreads, calendar: calendar)

        let initialSelection = organizer.initialSelection(for: today)

        #expect(initialSelection == nil)
    }

    // MARK: - Spread Containment Tests

    /// Conditions: Check if a year spread contains a given date.
    /// Expected: Returns true for dates within that year.
    @Test("Year spread contains dates within the year")
    func yearSpreadContainsDatesWithinYear() {
        let calendar = makeTestCalendar()
        let jan1 = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let dec31 = makeDate(year: 2026, month: 12, day: 31, calendar: calendar)
        let nextYear = makeDate(year: 2027, month: 1, day: 1, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: jan1, calendar: calendar)

        #expect(yearSpread.contains(date: jan1, calendar: calendar))
        #expect(yearSpread.contains(date: dec31, calendar: calendar))
        #expect(!yearSpread.contains(date: nextYear, calendar: calendar))
    }

    /// Conditions: Check if a month spread contains a given date.
    /// Expected: Returns true for dates within that month.
    @Test("Month spread contains dates within the month")
    func monthSpreadContainsDatesWithinMonth() {
        let calendar = makeTestCalendar()
        let jan1 = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let jan31 = makeDate(year: 2026, month: 1, day: 31, calendar: calendar)
        let feb1 = makeDate(year: 2026, month: 2, day: 1, calendar: calendar)

        let monthSpread = DataModel.Spread(period: .month, date: jan1, calendar: calendar)

        #expect(monthSpread.contains(date: jan1, calendar: calendar))
        #expect(monthSpread.contains(date: jan31, calendar: calendar))
        #expect(!monthSpread.contains(date: feb1, calendar: calendar))
    }

    /// Conditions: Check if a day spread contains a given date.
    /// Expected: Returns true only for that exact day.
    @Test("Day spread contains only the exact day")
    func daySpreadContainsOnlyExactDay() {
        let calendar = makeTestCalendar()
        let jan15 = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan16 = makeDate(year: 2026, month: 1, day: 16, calendar: calendar)

        let daySpread = DataModel.Spread(period: .day, date: jan15, calendar: calendar)

        #expect(daySpread.contains(date: jan15, calendar: calendar))
        #expect(!daySpread.contains(date: jan16, calendar: calendar))
    }

    /// Conditions: Check if a multiday spread contains a given date.
    /// Expected: Returns true for dates within the range.
    @Test("Multiday spread contains dates within the range")
    func multidaySpreadContainsDatesWithinRange() {
        let calendar = makeTestCalendar()
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan15 = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)
        let jan9 = makeDate(year: 2026, month: 1, day: 9, calendar: calendar)
        let jan21 = makeDate(year: 2026, month: 1, day: 21, calendar: calendar)

        let multidaySpread = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar)

        #expect(multidaySpread.contains(date: jan10, calendar: calendar))
        #expect(multidaySpread.contains(date: jan15, calendar: calendar))
        #expect(multidaySpread.contains(date: jan20, calendar: calendar))
        #expect(!multidaySpread.contains(date: jan9, calendar: calendar))
        #expect(!multidaySpread.contains(date: jan21, calendar: calendar))
    }
}

// MARK: - Hierarchy Display Tests

@Suite("Spread Hierarchy Display Tests")
struct SpreadHierarchyDisplayTests {

    private func makeTestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }

    /// Conditions: Year spread exists.
    /// Expected: Display label shows just the year (e.g., "2026").
    @Test("Year spread displays year number")
    func yearSpreadDisplaysYearNumber() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let spread = DataModel.Spread(period: .year, date: date, calendar: calendar)

        let label = spread.displayLabel(calendar: calendar)

        #expect(label == "2026")
    }

    /// Conditions: Month spread exists.
    /// Expected: Display label shows abbreviated month (e.g., "Jan").
    @Test("Month spread displays abbreviated month name")
    func monthSpreadDisplaysAbbreviatedMonth() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let spread = DataModel.Spread(period: .month, date: date, calendar: calendar)

        let label = spread.displayLabel(calendar: calendar)

        #expect(label == "Jan")
    }

    /// Conditions: Day spread exists.
    /// Expected: Display label shows day number (e.g., "15").
    @Test("Day spread displays day number")
    func daySpreadDisplaysDayNumber() {
        let calendar = makeTestCalendar()
        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        let label = spread.displayLabel(calendar: calendar)

        #expect(label == "15")
    }

    /// Conditions: Multiday spread exists.
    /// Expected: Display label shows date range (e.g., "10-20").
    @Test("Multiday spread displays date range")
    func multidaySpreadDisplaysDateRange() {
        let calendar = makeTestCalendar()
        let jan10 = makeDate(year: 2026, month: 1, day: 10, calendar: calendar)
        let jan20 = makeDate(year: 2026, month: 1, day: 20, calendar: calendar)
        let spread = DataModel.Spread(startDate: jan10, endDate: jan20, calendar: calendar)

        let label = spread.displayLabel(calendar: calendar)

        #expect(label == "10-20")
    }

    /// Conditions: Multiday spread spans two months.
    /// Expected: Display label shows month abbreviations (e.g., "Jan 28-Feb 3").
    @Test("Multiday spread spanning months shows both months")
    func multidaySpanningMonthsShowsBothMonths() {
        let calendar = makeTestCalendar()
        let jan28 = makeDate(year: 2026, month: 1, day: 28, calendar: calendar)
        let feb3 = makeDate(year: 2026, month: 2, day: 3, calendar: calendar)
        let spread = DataModel.Spread(startDate: jan28, endDate: feb3, calendar: calendar)

        let label = spread.displayLabel(calendar: calendar)

        #expect(label == "Jan 28-Feb 3")
    }
}
