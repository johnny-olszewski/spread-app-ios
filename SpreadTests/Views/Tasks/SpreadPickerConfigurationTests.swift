import Foundation
import Testing
@testable import Spread

/// Tests for SpreadPickerConfiguration.
///
/// Verifies:
/// - Chronological spread ordering matches spread tab bar
/// - Period filter toggle logic
/// - Multiday expansion date list generation
@Suite("SpreadPickerConfiguration Tests")
struct SpreadPickerConfigurationTests {

    // MARK: - Test Helpers

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Chronological Ordering Tests

    /// Tests that spreads are ordered chronologically with year → month → day hierarchy.
    /// Expects spreads sorted by date ascending within their hierarchy level.
    @Test("Spreads ordered chronologically")
    func spreadsOrderedChronologically() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2027, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 3, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 20, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let orderedSpreads = config.filteredSpreads(periods: Set(Period.allCases))

        // Should be: 2026 year, Jan 2026 month, Jan 15 day, Jan 20 day, Mar 2026 month, 2027 year
        #expect(orderedSpreads.count == 6)
        #expect(orderedSpreads[0].period == .year)
        #expect(calendar.component(.year, from: orderedSpreads[0].date) == 2026)
        #expect(orderedSpreads[1].period == .month)
        #expect(calendar.component(.month, from: orderedSpreads[1].date) == 1)
        #expect(orderedSpreads[2].period == .day)
        #expect(calendar.component(.day, from: orderedSpreads[2].date) == 15)
        #expect(orderedSpreads[3].period == .day)
        #expect(calendar.component(.day, from: orderedSpreads[3].date) == 20)
        #expect(orderedSpreads[4].period == .month)
        #expect(calendar.component(.month, from: orderedSpreads[4].date) == 3)
        #expect(orderedSpreads[5].period == .year)
        #expect(calendar.component(.year, from: orderedSpreads[5].date) == 2027)
    }

    // MARK: - Period Filter Tests

    /// Tests that filtering by year period returns only year spreads.
    /// Expects only spreads with period == .year in the result.
    @Test("Filter by year period only")
    func filterByYearOnly() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: [.year])

        #expect(filtered.count == 1)
        #expect(filtered[0].period == .year)
    }

    /// Tests that filtering by month period returns only month spreads.
    /// Expects only spreads with period == .month in the result.
    @Test("Filter by month period only")
    func filterByMonthOnly() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 2, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: [.month])

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.period == .month })
    }

    /// Tests that filtering by day period returns only day spreads.
    /// Expects only spreads with period == .day in the result.
    @Test("Filter by day period only")
    func filterByDayOnly() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 16, calendar: calendar), calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: [.day])

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.period == .day })
    }

    /// Tests that filtering by multiday period returns only multiday spreads.
    /// Expects only spreads with period == .multiday in the result.
    @Test("Filter by multiday period only")
    func filterByMultidayOnly() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let startDate = makeDate(year: 2026, month: 1, day: 13, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 1, day: 19, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: [.multiday])

        #expect(filtered.count == 1)
        #expect(filtered[0].period == .multiday)
    }

    /// Tests that filtering by multiple periods returns spreads matching any of the periods.
    /// Expects spreads with period in the filter set.
    @Test("Filter by multiple periods")
    func filterByMultiplePeriods() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: [.year, .day])

        #expect(filtered.count == 2)
        #expect(filtered.contains { $0.period == .year })
        #expect(filtered.contains { $0.period == .day })
        #expect(!filtered.contains { $0.period == .month })
    }

    /// Tests that filtering with all periods returns all spreads.
    /// Expects all spreads to be returned when all periods are selected.
    @Test("Filter with all periods returns all spreads")
    func filterWithAllPeriods() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let startDate = makeDate(year: 2026, month: 1, day: 13, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 1, day: 19, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar),
            DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: Set(Period.allCases))

        #expect(filtered.count == 4)
    }

    /// Tests that filtering with empty periods returns all spreads (no filter applied).
    /// Expects all spreads when no periods are selected, since the implementation
    /// treats an empty set as "show all."
    @Test("Filter with no periods returns all spreads")
    func filterWithNoPeriods() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spreads = [
            DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
            DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar),
        ]

        let config = SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )

        let filtered = config.filteredSpreads(periods: [])

        #expect(filtered.count == 2)
    }

    // MARK: - Multiday Expansion Tests

    /// Tests that multiday date list generation returns all contained dates.
    /// Expects dates from startDate to endDate inclusive.
    @Test("Multiday expansion generates all contained dates")
    func multidayExpansionGeneratesAllDates() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let startDate = makeDate(year: 2026, month: 1, day: 13, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 1, day: 17, calendar: calendar)

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [spread],
            calendar: calendar,
            today: today
        )

        let dates = config.containedDates(for: spread)

        // Jan 13, 14, 15, 16, 17 = 5 days
        #expect(dates.count == 5)
        #expect(calendar.component(.day, from: dates[0]) == 13)
        #expect(calendar.component(.day, from: dates[1]) == 14)
        #expect(calendar.component(.day, from: dates[2]) == 15)
        #expect(calendar.component(.day, from: dates[3]) == 16)
        #expect(calendar.component(.day, from: dates[4]) == 17)
    }

    /// Tests that multiday expansion across month boundary includes all dates.
    /// Expects dates spanning from one month to another.
    @Test("Multiday expansion across month boundary")
    func multidayExpansionAcrossMonthBoundary() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 30, calendar: calendar)

        let startDate = makeDate(year: 2026, month: 1, day: 30, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 2, day: 2, calendar: calendar)

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [spread],
            calendar: calendar,
            today: today
        )

        let dates = config.containedDates(for: spread)

        // Jan 30, 31, Feb 1, 2 = 4 days
        #expect(dates.count == 4)
        #expect(calendar.component(.month, from: dates[0]) == 1)
        #expect(calendar.component(.day, from: dates[0]) == 30)
        #expect(calendar.component(.month, from: dates[3]) == 2)
        #expect(calendar.component(.day, from: dates[3]) == 2)
    }

    /// Tests that multiday expansion for single-day range returns one date.
    /// Expects single date when startDate == endDate.
    @Test("Multiday expansion for single day")
    func multidayExpansionSingleDay() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let date = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spread = DataModel.Spread(startDate: date, endDate: date, calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [spread],
            calendar: calendar,
            today: today
        )

        let dates = config.containedDates(for: spread)

        #expect(dates.count == 1)
        #expect(calendar.component(.day, from: dates[0]) == 15)
    }

    /// Tests that multiday expansion returns empty for non-multiday spreads.
    /// Expects empty result for year/month/day spreads.
    @Test("Multiday expansion returns empty for non-multiday spreads")
    func multidayExpansionEmptyForNonMultiday() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [spread],
            calendar: calendar,
            today: today
        )

        let dates = config.containedDates(for: spread)

        #expect(dates.isEmpty)
    }

    // MARK: - Display Label Tests

    /// Tests that spread display labels are formatted correctly for picker.
    /// Expects human-readable labels for each period type.
    @Test("Spread display labels formatted correctly")
    func spreadDisplayLabelsFormatted() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: makeDate(year: 2026, month: 1, day: 1, calendar: calendar), calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: makeDate(year: 2026, month: 3, day: 1, calendar: calendar), calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: makeDate(year: 2026, month: 1, day: 15, calendar: calendar), calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [yearSpread, monthSpread, daySpread],
            calendar: calendar,
            today: today
        )

        let yearLabel = config.displayLabel(for: yearSpread)
        let monthLabel = config.displayLabel(for: monthSpread)
        let dayLabel = config.displayLabel(for: daySpread)

        #expect(yearLabel.contains("2026"))
        #expect(monthLabel.contains("Mar") || monthLabel.contains("March"))
        #expect(dayLabel.contains("15"))
    }

    /// Tests that multiday spread display labels show date range.
    /// Expects label with start and end dates.
    @Test("Multiday display label shows date range")
    func multidayDisplayLabelShowsRange() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)

        let startDate = makeDate(year: 2026, month: 1, day: 13, calendar: calendar)
        let endDate = makeDate(year: 2026, month: 1, day: 19, calendar: calendar)

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let config = SpreadPickerConfiguration(
            spreads: [spread],
            calendar: calendar,
            today: today
        )

        let label = config.displayLabel(for: spread)

        #expect(label.contains("13"))
        #expect(label.contains("19"))
    }
}
