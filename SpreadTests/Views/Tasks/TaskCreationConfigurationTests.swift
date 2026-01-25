import Foundation
import Testing
@testable import Spread

/// Tests for TaskCreationConfiguration validation logic.
@Suite("Task Creation Configuration Tests")
struct TaskCreationConfigurationTests {

    // MARK: - Test Helpers

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - Title Validation Tests

    /// Tests that an empty title is invalid.
    ///
    /// Condition: Title is an empty string.
    /// Expected: Validation fails with emptyTitle error.
    @Test("Empty title is invalid")
    func testEmptyTitleIsInvalid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("")

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Tests that a whitespace-only title is invalid.
    ///
    /// Condition: Title contains only spaces.
    /// Expected: Validation fails with emptyTitle error (no trimming applied).
    @Test("Whitespace-only title is invalid")
    func testWhitespaceOnlyTitleIsInvalid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("   ")

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Tests that a whitespace-only title with tabs and newlines is invalid.
    ///
    /// Condition: Title contains only whitespace characters (spaces, tabs, newlines).
    /// Expected: Validation fails with emptyTitle error.
    @Test("Whitespace with tabs and newlines is invalid")
    func testWhitespaceWithTabsIsInvalid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle(" \t\n ")

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Tests that a valid title passes validation.
    ///
    /// Condition: Title is a non-empty string with content.
    /// Expected: Validation succeeds.
    @Test("Valid title passes validation")
    func testValidTitlePassesValidation() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("Buy groceries")

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a title with leading whitespace is valid.
    ///
    /// Condition: Title has leading whitespace but also content.
    /// Expected: Validation succeeds (no trimming).
    @Test("Title with leading whitespace is valid")
    func testTitleWithLeadingWhitespaceIsValid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("  Buy groceries")

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    // MARK: - Date Validation Tests - Day Period

    /// Tests that today's date is valid for day period.
    ///
    /// Condition: Selected date is today with day period.
    /// Expected: Validation succeeds.
    @Test("Today is valid for day period")
    func testTodayIsValidForDayPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .day, date: today)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a future date is valid for day period.
    ///
    /// Condition: Selected date is tomorrow with day period.
    /// Expected: Validation succeeds.
    @Test("Future date is valid for day period")
    func testFutureDateIsValidForDayPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let futureDate = Self.makeDate(year: 2026, month: 1, day: 16)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .day, date: futureDate)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a past date is invalid for day period.
    ///
    /// Condition: Selected date is yesterday with day period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past date is invalid for day period")
    func testPastDateIsInvalidForDayPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let pastDate = Self.makeDate(year: 2026, month: 1, day: 14)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .day, date: pastDate)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Date Validation Tests - Month Period

    /// Tests that the current month is valid for month period.
    ///
    /// Condition: Selected date is in the current month with month period.
    /// Expected: Validation succeeds (period-normalized comparison).
    @Test("Current month is valid for month period")
    func testCurrentMonthIsValidForMonthPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        // Even early in the month should be valid when comparing normalized dates
        let earlyInMonth = Self.makeDate(year: 2026, month: 1, day: 1)
        let result = config.validateDate(period: .month, date: earlyInMonth)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a future month is valid for month period.
    ///
    /// Condition: Selected date is in the next month with month period.
    /// Expected: Validation succeeds.
    @Test("Future month is valid for month period")
    func testFutureMonthIsValidForMonthPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let futureMonth = Self.makeDate(year: 2026, month: 2, day: 1)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .month, date: futureMonth)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a past month is invalid for month period.
    ///
    /// Condition: Selected date is in the previous month with month period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past month is invalid for month period")
    func testPastMonthIsInvalidForMonthPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 2, day: 15)
        let pastMonth = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .month, date: pastMonth)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Date Validation Tests - Year Period

    /// Tests that the current year is valid for year period.
    ///
    /// Condition: Selected date is in the current year with year period.
    /// Expected: Validation succeeds (period-normalized comparison).
    @Test("Current year is valid for year period")
    func testCurrentYearIsValidForYearPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 6, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        // Even early in the year should be valid when comparing normalized dates
        let earlyInYear = Self.makeDate(year: 2026, month: 1, day: 1)
        let result = config.validateDate(period: .year, date: earlyInYear)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a future year is valid for year period.
    ///
    /// Condition: Selected date is in the next year with year period.
    /// Expected: Validation succeeds.
    @Test("Future year is valid for year period")
    func testFutureYearIsValidForYearPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 6, day: 15)
        let futureYear = Self.makeDate(year: 2027, month: 1, day: 1)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .year, date: futureYear)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that a past year is invalid for year period.
    ///
    /// Condition: Selected date is in the previous year with year period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past year is invalid for year period")
    func testPastYearIsInvalidForYearPeriod() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 6, day: 15)
        let pastYear = Self.makeDate(year: 2025, month: 12, day: 31)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .year, date: pastYear)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Combined Validation Tests

    /// Tests that a valid title and date pass full validation.
    ///
    /// Condition: Valid title and present date.
    /// Expected: Full validation succeeds.
    @Test("Valid title and date pass full validation")
    func testValidTitleAndDatePassFullValidation() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validate(title: "Buy groceries", period: .day, date: today)

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Tests that an invalid title fails full validation even with valid date.
    ///
    /// Condition: Empty title with valid date.
    /// Expected: Full validation fails with emptyTitle error.
    @Test("Invalid title fails full validation")
    func testInvalidTitleFailsFullValidation() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validate(title: "", period: .day, date: today)

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Tests that an invalid date fails full validation even with valid title.
    ///
    /// Condition: Valid title with past date.
    /// Expected: Full validation fails with pastDate error.
    @Test("Invalid date fails full validation")
    func testInvalidDateFailsFullValidation() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let pastDate = Self.makeDate(year: 2026, month: 1, day: 14)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let result = config.validate(title: "Buy groceries", period: .day, date: pastDate)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Default Selection Tests

    /// Tests default selection when no spread is selected.
    ///
    /// Condition: No spread selected.
    /// Expected: Defaults to day period and today's date.
    @Test("Default selection without spread uses day period and today")
    func testDefaultSelectionWithoutSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let (period, date) = config.defaultSelection(from: nil)

        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: today))
    }

    /// Tests default selection with a day spread selected.
    ///
    /// Condition: Day spread selected.
    /// Expected: Uses the spread's period and date.
    @Test("Default selection with day spread uses spread's period and date")
    @MainActor
    func testDefaultSelectionWithDaySpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let spreadDate = Self.makeDate(year: 2026, month: 1, day: 20)
        let spread = DataModel.Spread(period: .day, date: spreadDate, calendar: calendar)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let (period, date) = config.defaultSelection(from: spread)

        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: spreadDate))
    }

    /// Tests default selection with a month spread selected.
    ///
    /// Condition: Month spread selected.
    /// Expected: Uses the spread's period and date.
    @Test("Default selection with month spread uses spread's period and date")
    @MainActor
    func testDefaultSelectionWithMonthSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let spreadDate = Self.makeDate(year: 2026, month: 2, day: 1)
        let spread = DataModel.Spread(period: .month, date: spreadDate, calendar: calendar)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let (period, date) = config.defaultSelection(from: spread)

        #expect(period == .month)
        // Month spread normalizes to first of month
        let normalizedSpreadDate = Period.month.normalizeDate(spreadDate, calendar: calendar)
        #expect(date == normalizedSpreadDate)
    }

    /// Tests default selection with a year spread selected.
    ///
    /// Condition: Year spread selected.
    /// Expected: Uses the spread's period and date.
    @Test("Default selection with year spread uses spread's period and date")
    @MainActor
    func testDefaultSelectionWithYearSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let spreadDate = Self.makeDate(year: 2027, month: 1, day: 1)
        let spread = DataModel.Spread(period: .year, date: spreadDate, calendar: calendar)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let (period, date) = config.defaultSelection(from: spread)

        #expect(period == .year)
        // Year spread normalizes to first of year
        let normalizedSpreadDate = Period.year.normalizeDate(spreadDate, calendar: calendar)
        #expect(date == normalizedSpreadDate)
    }

    /// Tests default selection with a multiday spread selected.
    ///
    /// Condition: Multiday spread selected.
    /// Expected: Defaults to day period (multiday can't have tasks assigned) and spread's start date.
    @Test("Default selection with multiday spread uses day period and start date")
    @MainActor
    func testDefaultSelectionWithMultidaySpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let startDate = Self.makeDate(year: 2026, month: 1, day: 20)
        let endDate = Self.makeDate(year: 2026, month: 1, day: 26)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let config = TaskCreationConfiguration(calendar: calendar, today: today)

        let (period, date) = config.defaultSelection(from: spread)

        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: startDate))
    }

    // MARK: - Assignable Periods Tests

    /// Tests that assignable periods are year, month, and day only.
    ///
    /// Condition: Check assignablePeriods static property.
    /// Expected: Contains year, month, day but not multiday.
    @Test("Assignable periods are year, month, and day only")
    func testAssignablePeriodsExcludeMultiday() {
        let periods = TaskCreationConfiguration.assignablePeriods

        #expect(periods.contains(.year))
        #expect(periods.contains(.month))
        #expect(periods.contains(.day))
        #expect(!periods.contains(.multiday))
    }
}
