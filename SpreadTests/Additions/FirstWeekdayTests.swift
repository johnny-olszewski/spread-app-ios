import Foundation
import Testing
@testable import Spread

struct FirstWeekdayTests {

    // MARK: - Test Helpers

    /// Creates a calendar for testing with a specific first weekday.
    private func makeCalendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// Creates a date for testing.
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = makeCalendar(firstWeekday: 1)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    // MARK: - Display Name Tests

    @Test func testSystemDefaultDisplayName() {
        #expect(FirstWeekday.systemDefault.displayName == "System Default")
    }

    @Test func testSundayDisplayName() {
        #expect(FirstWeekday.sunday.displayName == "Sunday")
    }

    @Test func testMondayDisplayName() {
        #expect(FirstWeekday.monday.displayName == "Monday")
    }

    // MARK: - Weekday Value Tests

    @Test func testSundayWeekdayValue() {
        let calendar = makeCalendar(firstWeekday: 1)
        #expect(FirstWeekday.sunday.weekdayValue(using: calendar) == 1)
    }

    @Test func testMondayWeekdayValue() {
        let calendar = makeCalendar(firstWeekday: 1)
        #expect(FirstWeekday.monday.weekdayValue(using: calendar) == 2)
    }

    @Test func testSystemDefaultUsesCalendarFirstWeekday() {
        let sundayCalendar = makeCalendar(firstWeekday: 1)
        #expect(FirstWeekday.systemDefault.weekdayValue(using: sundayCalendar) == 1)

        let mondayCalendar = makeCalendar(firstWeekday: 2)
        #expect(FirstWeekday.systemDefault.weekdayValue(using: mondayCalendar) == 2)
    }

    // MARK: - Configured Calendar Tests

    @Test func testConfiguredCalendarWithSunday() {
        let baseCalendar = makeCalendar(firstWeekday: 2)
        let configured = FirstWeekday.sunday.configuredCalendar(from: baseCalendar)
        #expect(configured.firstWeekday == 1)
    }

    @Test func testConfiguredCalendarWithMonday() {
        let baseCalendar = makeCalendar(firstWeekday: 1)
        let configured = FirstWeekday.monday.configuredCalendar(from: baseCalendar)
        #expect(configured.firstWeekday == 2)
    }

    @Test func testConfiguredCalendarWithSystemDefault() {
        let baseCalendar = makeCalendar(firstWeekday: 1)
        let configured = FirstWeekday.systemDefault.configuredCalendar(from: baseCalendar)
        #expect(configured.firstWeekday == 1)
    }

    // MARK: - CaseIterable Tests

    @Test func testAllCasesContainsThreeValues() {
        #expect(FirstWeekday.allCases.count == 3)
    }

    @Test func testAllCasesContainsExpectedValues() {
        let allCases = FirstWeekday.allCases
        #expect(allCases.contains(.systemDefault))
        #expect(allCases.contains(.sunday))
        #expect(allCases.contains(.monday))
    }

    // MARK: - Raw Value Tests

    @Test func testSystemDefaultRawValue() {
        #expect(FirstWeekday.systemDefault.rawValue == "systemDefault")
    }

    @Test func testSundayRawValue() {
        #expect(FirstWeekday.sunday.rawValue == "sunday")
    }

    @Test func testMondayRawValue() {
        #expect(FirstWeekday.monday.rawValue == "monday")
    }

    @Test func testInitFromRawValue() {
        #expect(FirstWeekday(rawValue: "systemDefault") == .systemDefault)
        #expect(FirstWeekday(rawValue: "sunday") == .sunday)
        #expect(FirstWeekday(rawValue: "monday") == .monday)
        #expect(FirstWeekday(rawValue: "invalid") == nil)
    }

    // MARK: - First Day of Week Tests

    @Test func testFirstDayOfWeekWithSundayStart() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Wednesday, January 8, 2026
        let date = makeDate(year: 2026, month: 1, day: 8)
        let result = date.firstDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be Sunday, January 4, 2026
        let expected = makeDate(year: 2026, month: 1, day: 4)
        #expect(result == expected)
    }

    @Test func testFirstDayOfWeekWithMondayStart() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Wednesday, January 8, 2026
        let date = makeDate(year: 2026, month: 1, day: 8)
        let result = date.firstDayOfWeek(calendar: calendar, firstWeekday: .monday)

        // Should be Monday, January 5, 2026
        let expected = makeDate(year: 2026, month: 1, day: 5)
        #expect(result == expected)
    }

    @Test func testFirstDayOfWeekOnSunday() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Sunday, January 4, 2026
        let date = makeDate(year: 2026, month: 1, day: 4)
        let result = date.firstDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be same day
        let expected = makeDate(year: 2026, month: 1, day: 4)
        #expect(result == expected)
    }

    @Test func testFirstDayOfWeekOnMonday() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Monday, January 5, 2026
        let date = makeDate(year: 2026, month: 1, day: 5)
        let result = date.firstDayOfWeek(calendar: calendar, firstWeekday: .monday)

        // Should be same day
        let expected = makeDate(year: 2026, month: 1, day: 5)
        #expect(result == expected)
    }

    @Test func testFirstDayOfWeekAcrossMonthBoundary() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Tuesday, February 3, 2026
        let date = makeDate(year: 2026, month: 2, day: 3)
        let result = date.firstDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be Sunday, February 1, 2026
        let expected = makeDate(year: 2026, month: 2, day: 1)
        #expect(result == expected)
    }

    @Test func testFirstDayOfWeekAcrossYearBoundary() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Friday, January 2, 2026
        let date = makeDate(year: 2026, month: 1, day: 2)
        let result = date.firstDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be Sunday, December 28, 2025
        let expected = makeDate(year: 2025, month: 12, day: 28)
        #expect(result == expected)
    }

    // MARK: - Last Day of Week Tests

    @Test func testLastDayOfWeekWithSundayStart() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Wednesday, January 8, 2026
        let date = makeDate(year: 2026, month: 1, day: 8)
        let result = date.lastDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be Saturday, January 10, 2026
        let expected = makeDate(year: 2026, month: 1, day: 10)
        #expect(result == expected)
    }

    @Test func testLastDayOfWeekWithMondayStart() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Wednesday, January 8, 2026
        let date = makeDate(year: 2026, month: 1, day: 8)
        let result = date.lastDayOfWeek(calendar: calendar, firstWeekday: .monday)

        // Should be Sunday, January 11, 2026
        let expected = makeDate(year: 2026, month: 1, day: 11)
        #expect(result == expected)
    }

    @Test func testLastDayOfWeekOnSaturday() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Saturday, January 10, 2026
        let date = makeDate(year: 2026, month: 1, day: 10)
        let result = date.lastDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be same day
        let expected = makeDate(year: 2026, month: 1, day: 10)
        #expect(result == expected)
    }

    @Test func testLastDayOfWeekAcrossMonthBoundary() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Wednesday, January 28, 2026
        let date = makeDate(year: 2026, month: 1, day: 28)
        let result = date.lastDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be Saturday, January 31, 2026
        let expected = makeDate(year: 2026, month: 1, day: 31)
        #expect(result == expected)
    }

    @Test func testLastDayOfWeekAcrossYearBoundary() {
        let calendar = makeCalendar(firstWeekday: 1)
        // Tuesday, December 29, 2025
        let date = makeDate(year: 2025, month: 12, day: 29)
        let result = date.lastDayOfWeek(calendar: calendar, firstWeekday: .sunday)

        // Should be Saturday, January 3, 2026
        let expected = makeDate(year: 2026, month: 1, day: 3)
        #expect(result == expected)
    }

    // MARK: - Week Calculation Consistency Tests

    @Test func testWeekSpanIsSevenDays() {
        let calendar = makeCalendar(firstWeekday: 1)
        let date = makeDate(year: 2026, month: 6, day: 15)

        let firstDay = date.firstDayOfWeek(calendar: calendar, firstWeekday: .sunday)!
        let lastDay = date.lastDayOfWeek(calendar: calendar, firstWeekday: .sunday)!

        let daysDifference = calendar.dateComponents([.day], from: firstDay, to: lastDay).day!
        #expect(daysDifference == 6)
    }

    @Test func testWeekSpanIsSevenDaysWithMondayStart() {
        let calendar = makeCalendar(firstWeekday: 1)
        let date = makeDate(year: 2026, month: 6, day: 15)

        let firstDay = date.firstDayOfWeek(calendar: calendar, firstWeekday: .monday)!
        let lastDay = date.lastDayOfWeek(calendar: calendar, firstWeekday: .monday)!

        let daysDifference = calendar.dateComponents([.day], from: firstDay, to: lastDay).day!
        #expect(daysDifference == 6)
    }
}
