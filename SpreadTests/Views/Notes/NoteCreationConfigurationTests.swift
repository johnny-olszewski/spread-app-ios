import Foundation
import Testing
@testable import Spread

/// Tests for NoteCreationConfiguration validation logic.
@Suite("Note Creation Configuration Tests")
struct NoteCreationConfigurationTests {

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
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("")

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Condition: Title contains only spaces.
    /// Expected: Validation fails with emptyTitle error.
    @Test("Whitespace-only title is invalid")
    func testWhitespaceOnlyTitleIsInvalid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("   ")

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    /// Condition: Title is a valid non-empty string.
    /// Expected: Validation succeeds.
    @Test("Valid title passes validation")
    func testValidTitlePasses() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateTitle("Meeting notes")

        #expect(result.isValid)
        #expect(result.error == nil)
    }

    // MARK: - Date Validation Tests

    /// Condition: Date is today for day period.
    /// Expected: Validation succeeds.
    @Test("Today's date is valid for day period")
    func testTodayDateIsValidForDay() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .day, date: today)

        #expect(result.isValid)
    }

    /// Condition: Date is yesterday for day period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past date is invalid for day period")
    func testPastDateIsInvalidForDay() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let yesterday = Self.makeDate(year: 2026, month: 1, day: 14)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .day, date: yesterday)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    /// Condition: Date is in a future month for month period.
    /// Expected: Validation succeeds.
    @Test("Future month date is valid")
    func testFutureMonthDateIsValid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let futureMonth = Self.makeDate(year: 2026, month: 3, day: 1)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .month, date: futureMonth)

        #expect(result.isValid)
    }

    /// Condition: Date is in a past month for month period.
    /// Expected: Validation fails with pastDate error.
    @Test("Past month date is invalid")
    func testPastMonthDateIsInvalid() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 3, day: 15)
        let pastMonth = Self.makeDate(year: 2026, month: 2, day: 1)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validateDate(period: .month, date: pastMonth)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Combined Validation Tests

    /// Condition: Both title and date are valid.
    /// Expected: Combined validation succeeds.
    @Test("Valid title and date pass combined validation")
    func testValidCombinedValidation() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validate(title: "Test note", period: .day, date: today)

        #expect(result.isValid)
    }

    /// Condition: Title is empty but date is valid.
    /// Expected: Combined validation fails with emptyTitle (title checked first).
    @Test("Empty title fails combined validation")
    func testEmptyTitleFailsCombinedValidation() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let result = config.validate(title: "", period: .day, date: today)

        #expect(!result.isValid)
        #expect(result.error == .emptyTitle)
    }

    // MARK: - Default Selection Tests

    /// Condition: No spread is selected.
    /// Expected: Defaults to day period with today's date.
    @Test("Default selection without spread uses day and today")
    func testDefaultSelectionWithoutSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let (period, date) = config.defaultSelection(from: nil)

        #expect(period == .day)
        #expect(date == today)
    }

    /// Condition: A month spread is selected.
    /// Expected: Defaults to month period with the spread's date.
    @Test("Default selection with month spread uses month period")
    func testDefaultSelectionWithMonthSpread() {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 1, day: 15)
        let config = NoteCreationConfiguration(calendar: calendar, today: today)

        let spread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let (period, _) = config.defaultSelection(from: spread)

        #expect(period == .month)
    }

    // MARK: - Assignable Periods

    /// Condition: Request assignable periods.
    /// Expected: Returns year, month, day (excludes multiday).
    @Test("Assignable periods exclude multiday")
    func testAssignablePeriodsExcludeMultiday() {
        let periods = NoteCreationConfiguration.assignablePeriods

        #expect(periods == [.year, .month, .day])
        #expect(!periods.contains(.multiday))
    }
}
