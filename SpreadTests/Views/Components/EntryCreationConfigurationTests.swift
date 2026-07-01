import Foundation
import Testing
@testable import Spread

/// Tests for EntryCreationConfiguration — the unified validation config for all entry types.
@Suite("Entry Creation Configuration Tests")
struct EntryCreationConfigurationTests {

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

    /// Condition: Title is an empty string.
    /// Expected: Validation fails with emptyTitle error.
    @Test("Empty title is invalid")
    func testEmptyTitleIsInvalid() {
        let config = EntryCreationConfiguration(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 1, day: 15)
        )
        let result = config.validateTitle("")
        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Condition: Title contains only spaces.
    /// Expected: Validation fails with emptyTitle error.
    @Test("Whitespace-only title is invalid")
    func testWhitespaceOnlyTitleIsInvalid() {
        let config = EntryCreationConfiguration(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 1, day: 15)
        )
        let result = config.validateTitle("   ")
        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Condition: Title contains only whitespace characters (spaces, tabs, newlines).
    /// Expected: Validation fails with emptyTitle error.
    @Test("Whitespace with tabs and newlines is invalid")
    func testWhitespaceWithTabsIsInvalid() {
        let config = EntryCreationConfiguration(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 1, day: 15)
        )
        let result = config.validateTitle(" \t\n ")
        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Condition: Title is a non-empty string with content.
    /// Expected: Validation succeeds.
    @Test("Valid title passes validation")
    func testValidTitlePassesValidation() {
        let config = EntryCreationConfiguration(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 1, day: 15)
        )
        let result = config.validateTitle("Buy groceries")
        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Condition: Title has leading whitespace but also content.
    /// Expected: Validation succeeds (no trimming).
    @Test("Title with leading whitespace is valid")
    func testTitleWithLeadingWhitespaceIsValid() {
        let config = EntryCreationConfiguration(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 1, day: 15)
        )
        let result = config.validateTitle("  Buy groceries")
        #expect(result.isValid)
        #expect(result.error == nil)
    }

    // MARK: - Date Validation Tests - Day Period

    /// Condition: Selected date is today with day period.
    /// Expected: Validation succeeds.
    @Test("Today is valid for day period")
    func testTodayIsValidForDayPeriod() {
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .day, date: today)
        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Condition: Selected date is tomorrow with day period.
    /// Expected: Validation succeeds.
    @Test("Future date is valid for day period")
    func testFutureDateIsValidForDayPeriod() {
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .day, date: Self.makeDate(year: 2026, month: 1, day: 16))
        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Condition: Selected date is yesterday with day period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past date is invalid for day period")
    func testPastDateIsInvalidForDayPeriod() {
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .day, date: Self.makeDate(year: 2026, month: 1, day: 14))
        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Date Validation Tests - Month Period

    /// Condition: Selected date is early in the current month with month period.
    /// Expected: Validation succeeds (period-normalized comparison).
    @Test("Current month is valid for month period")
    func testCurrentMonthIsValidForMonthPeriod() {
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .month, date: Self.makeDate(year: 2026, month: 1, day: 1))
        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Condition: Selected date is in the previous month with month period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past month is invalid for month period")
    func testPastMonthIsInvalidForMonthPeriod() {
        let today = Self.makeDate(year: 2026, month: 2, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .month, date: Self.makeDate(year: 2026, month: 1, day: 15))
        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Date Validation Tests - Year Period

    /// Condition: Selected date is early in the current year with year period.
    /// Expected: Validation succeeds (period-normalized comparison).
    @Test("Current year is valid for year period")
    func testCurrentYearIsValidForYearPeriod() {
        let today = Self.makeDate(year: 2026, month: 6, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .year, date: Self.makeDate(year: 2026, month: 1, day: 1))
        #expect(result.isValid)
        #expect(result.error == nil)
    }

    /// Condition: Selected date is in the previous year with year period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past year is invalid for year period")
    func testPastYearIsInvalidForYearPeriod() {
        let today = Self.makeDate(year: 2026, month: 6, day: 15)
        let config = EntryCreationConfiguration(calendar: Self.makeCalendar(), today: today)
        let result = config.validateDate(period: .year, date: Self.makeDate(year: 2025, month: 12, day: 31))
        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Default Selection Tests

    /// Condition: No spread is selected.
    /// Expected: Defaults to day period and today's date.
    @Test("Default selection without spread uses day period and today")
    func testDefaultSelectionWithoutSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = EntryCreationConfiguration(calendar: calendar, today: today)
        let (period, date) = config.defaultSelection(from: nil)
        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: today))
    }

    /// Condition: A day spread is selected.
    /// Expected: Uses the spread's period and date.
    @Test("Default selection with day spread uses spread's period and date")
    @MainActor
    func testDefaultSelectionWithDaySpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let spreadDate = Self.makeDate(year: 2026, month: 1, day: 20)
        let spread = DataModel.Spread(period: .day, date: spreadDate, calendar: calendar)
        let config = EntryCreationConfiguration(calendar: calendar, today: today)
        let (period, date) = config.defaultSelection(from: spread)
        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: spreadDate))
    }

    /// Condition: A month spread is selected.
    /// Expected: Uses the spread's period and date.
    @Test("Default selection with month spread uses spread's period and date")
    @MainActor
    func testDefaultSelectionWithMonthSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let spreadDate = Self.makeDate(year: 2026, month: 2, day: 1)
        let spread = DataModel.Spread(period: .month, date: spreadDate, calendar: calendar)
        let config = EntryCreationConfiguration(calendar: calendar, today: today)
        let (period, date) = config.defaultSelection(from: spread)
        #expect(period == .month)
        #expect(date == Period.month.normalizeDate(spreadDate, calendar: calendar))
    }

    /// Condition: Multiday spread selected, today is before the range starts.
    /// Expected: Defaults to day period with the range's start date.
    @Test("Default selection with multiday spread (today outside range) uses day period and start date")
    @MainActor
    func testDefaultSelectionWithMultidaySpreadTodayOutsideRange() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let startDate = Self.makeDate(year: 2026, month: 1, day: 20)
        let endDate = Self.makeDate(year: 2026, month: 1, day: 26)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let config = EntryCreationConfiguration(calendar: calendar, today: today)
        let (period, date) = config.defaultSelection(from: spread)
        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: startDate))
    }

    /// Condition: Multiday spread selected, today falls within the range.
    /// Expected: Defaults to day period with today's date.
    @Test("Default selection with multiday spread (today inside range) uses day period and today")
    @MainActor
    func testDefaultSelectionWithMultidaySpreadTodayInsideRange() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let startDate = Self.makeDate(year: 2026, month: 1, day: 13)
        let endDate = Self.makeDate(year: 2026, month: 1, day: 19)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let config = EntryCreationConfiguration(calendar: calendar, today: today)
        let (period, date) = config.defaultSelection(from: spread)
        #expect(period == .day)
        #expect(calendar.isDate(date, inSameDayAs: today))
    }

    // MARK: - Assignable Periods Tests

    /// Condition: Check assignablePeriods static property.
    /// Expected: Contains year, month, multiday, and day — applies equally to Task and Note entry types.
    @Test("Assignable periods include year, month, multiday, day")
    func testAssignablePeriodsContainAllPeriods() {
        let periods = EntryCreationConfiguration.assignablePeriods
        #expect(periods == [.year, .month, .multiday, .day])
    }
}
