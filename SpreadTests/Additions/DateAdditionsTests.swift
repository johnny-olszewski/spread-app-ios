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

    @Test func testFirstDayOfYearFromMidYear() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfYearFromJanuaryFirst() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfYearFromDecemberThirtyFirst() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfYearAcrossLeapYear() {
        let date = makeDate(year: 2024, month: 2, day: 29)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2024, month: 1, day: 1)
        #expect(result == expected)
    }

    // MARK: - firstDayOfMonth Tests

    @Test func testFirstDayOfMonthFromMidMonth() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfMonthFromFirstOfMonth() {
        let date = makeDate(year: 2026, month: 6, day: 1)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfMonthFromLastOfMonth() {
        let date = makeDate(year: 2026, month: 1, day: 31)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfMonthFebruaryLeapYear() {
        let date = makeDate(year: 2024, month: 2, day: 29)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2024, month: 2, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfMonthFebruaryNonLeapYear() {
        let date = makeDate(year: 2025, month: 2, day: 28)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2025, month: 2, day: 1)
        #expect(result == expected)
    }

    // MARK: - startOfDay Tests

    @Test func testStartOfDayFromMorning() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 9, minute: 30)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    @Test func testStartOfDayFromMidday() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 12, minute: 0)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    @Test func testStartOfDayFromLateNight() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 23, minute: 59)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    @Test func testStartOfDayFromMidnight() {
        let date = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        let result = date.startOfDay(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15, hour: 0, minute: 0)
        #expect(result == expected)
    }

    // MARK: - Date.getDate Tests

    @Test func testDateFromValidComponents() {
        let result = Date.getDate(calendar: testCalendar, year: 2026, month: 6, day: 15)

        let expected = makeDate(year: 2026, month: 6, day: 15)
        #expect(result == expected)
    }

    @Test func testDateFromJanuaryFirst() {
        let result = Date.getDate(calendar: testCalendar, year: 2026, month: 1, day: 1)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testDateFromDecemberThirtyFirst() {
        let result = Date.getDate(calendar: testCalendar, year: 2026, month: 12, day: 31)

        let expected = makeDate(year: 2026, month: 12, day: 31)
        #expect(result == expected)
    }

    @Test func testDateFromLeapDay() {
        let result = Date.getDate(calendar: testCalendar, year: 2024, month: 2, day: 29)

        let expected = makeDate(year: 2024, month: 2, day: 29)
        #expect(result == expected)
    }

    // MARK: - Year Boundary Tests

    @Test func testFirstDayOfYearAtYearBoundary() {
        let date = makeDate(year: 2025, month: 12, day: 31, hour: 23, minute: 59)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2025, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfMonthAtMonthBoundary() {
        let date = makeDate(year: 2026, month: 1, day: 31, hour: 23, minute: 59)
        let result = date.firstDayOfMonth(calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(result == expected)
    }

    // MARK: - Different Years Tests

    @Test func testFirstDayOfYearFor2025() {
        let date = makeDate(year: 2025, month: 7, day: 4)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2025, month: 1, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfYearFor2030() {
        let date = makeDate(year: 2030, month: 3, day: 15)
        let result = date.firstDayOfYear(calendar: testCalendar)

        let expected = makeDate(year: 2030, month: 1, day: 1)
        #expect(result == expected)
    }
}
