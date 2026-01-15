import Foundation
import Testing
@testable import Spread

struct DateAdditionsTests {

    // MARK: - Test Helpers

    /// Creates a calendar for testing with a specific time zone.
    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Creates a date for testing.
    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return testCalendar.date(from: components)!
    }

    // MARK: - firstDayOfYear Tests

    /// Conditions: Date is June 15, 2026 (mid-year).
    /// Expected: Should return January 1, 2026.
    @Test func testFirstDayOfYearFromMidYear() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is already January 1, 2026.
    /// Expected: Should return the same date (January 1, 2026).
    @Test func testFirstDayOfYearFromJanuaryFirst() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is December 31, 2026 (last day of year).
    /// Expected: Should return January 1, 2026.
    @Test func testFirstDayOfYearFromDecemberThirtyFirst() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is February 29, 2024 (leap year).
    /// Expected: Should return January 1, 2024.
    @Test func testFirstDayOfYearAcrossLeapYear() {
        let date = makeDate(year: 2024, month: 2, day: 29)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2024, month: 1, day: 1)
        #expect(result == expected)
    }

    // MARK: - firstDayOfMonth Tests

    /// Conditions: Date is June 15, 2026 (mid-month).
    /// Expected: Should return June 1, 2026.
    @Test func testFirstDayOfMonthFromMidMonth() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is already June 1, 2026 (first of month).
    /// Expected: Should return the same date.
    @Test func testFirstDayOfMonthFromFirstOfMonth() {
        let date = makeDate(year: 2026, month: 6, day: 1)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is January 31, 2026 (last day of month).
    /// Expected: Should return January 1, 2026.
    @Test func testFirstDayOfMonthFromLastOfMonth() {
        let date = makeDate(year: 2026, month: 1, day: 31)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is February 29, 2024 (leap year).
    /// Expected: Should return February 1, 2024.
    @Test func testFirstDayOfMonthFebruaryLeapYear() {
        let date = makeDate(year: 2024, month: 2, day: 29)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2024, month: 2, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is February 28, 2025 (non-leap year).
    /// Expected: Should return February 1, 2025.
    @Test func testFirstDayOfMonthFebruaryNonLeapYear() {
        let date = makeDate(year: 2025, month: 2, day: 28)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2025, month: 2, day: 1)
        #expect(result == expected)
    }

    // MARK: - startOfDay Tests

    /// Conditions: Date is 9:30 AM on June 15, 2026.
    /// Expected: Should return midnight (00:00) on June 15, 2026.
    @Test func testStartOfDayFromMorning() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 9, minute: 30)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    /// Conditions: Date is 12:00 PM (noon) on June 15, 2026.
    /// Expected: Should return midnight (00:00) on June 15, 2026.
    @Test func testStartOfDayFromMidday() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 12, minute: 0)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    /// Conditions: Date is 11:59 PM on June 15, 2026.
    /// Expected: Should return midnight (00:00) on June 15, 2026.
    @Test func testStartOfDayFromLateNight() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 23, minute: 59)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    /// Conditions: Date is already midnight (00:00) on June 15, 2026.
    /// Expected: Should return the same date/time.
    @Test func testStartOfDayFromMidnight() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    // MARK: - Date.getDate Tests

    /// Conditions: Valid date components (June 15, 2026).
    /// Expected: Should return the corresponding date.
    @Test func testDateFromValidComponents() {
        let result = Date.getDate(calendar: testCalendar, year: 2026, month: 6, day: 15)

        let expected = makeDate(year: 2026, month: 6, day: 15)
        #expect(result == expected)
    }

    /// Conditions: January 1, 2026 (first day of year).
    /// Expected: Should return January 1, 2026.
    @Test func testDateFromJanuaryFirst() {
        let result = Date.getDate(calendar: testCalendar, year: 2026, month: 1, day: 1)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: December 31, 2026 (last day of year).
    /// Expected: Should return December 31, 2026.
    @Test func testDateFromDecemberThirtyFirst() {
        let result = Date.getDate(calendar: testCalendar, year: 2026, month: 12, day: 31)

        let expected = makeDate(year: 2026, month: 12, day: 31)
        #expect(result == expected)
    }

    /// Conditions: February 29, 2024 (leap day).
    /// Expected: Should return February 29, 2024.
    @Test func testDateFromLeapDay() {
        let result = Date.getDate(calendar: testCalendar, year: 2024, month: 2, day: 29)

        let expected = makeDate(year: 2024, month: 2, day: 29)
        #expect(result == expected)
    }

    // MARK: - Year Boundary Tests

    /// Conditions: Date is 11:59 PM on December 31, 2025.
    /// Expected: Should return January 1, 2025 (same year, not next).
    @Test func testFirstDayOfYearAtYearBoundary() {
        let date = makeDate(year: 2025, month: 12, day: 31, hour: 23, minute: 59)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2025, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is 11:59 PM on January 31, 2026.
    /// Expected: Should return January 1, 2026.
    @Test func testFirstDayOfMonthAtMonthBoundary() {
        let date = makeDate(year: 2026, month: 1, day: 31, hour: 23, minute: 59)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    // MARK: - Different Years Tests

    /// Conditions: Date is July 4, 2025.
    /// Expected: Should return January 1, 2025.
    @Test func testFirstDayOfYearFor2025() {
        let date = makeDate(year: 2025, month: 7, day: 4)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2025, month: 1, day: 1)
        #expect(result == expected)
    }

    /// Conditions: Date is March 15, 2030.
    /// Expected: Should return January 1, 2030.
    @Test func testFirstDayOfYearFor2030() {
        let date = makeDate(year: 2030, month: 3, day: 15)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2030, month: 1, day: 1)
        #expect(result == expected)
    }
}
