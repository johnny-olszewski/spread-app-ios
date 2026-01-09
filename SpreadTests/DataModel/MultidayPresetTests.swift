import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.DateComponents
import struct Foundation.TimeZone
import Testing
@testable import Spread

struct MultidayPresetTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return testCalendar.date(from: components)!
    }

    // MARK: - Display Name Tests

    @Test func testThisWeekDisplayName() {
        #expect(MultidayPreset.thisWeek.displayName == "This Week")
    }

    @Test func testNextWeekDisplayName() {
        #expect(MultidayPreset.nextWeek.displayName == "Next Week")
    }

    // MARK: - All Cases Tests

    @Test func testAllCasesContainsTwoPresets() {
        #expect(MultidayPreset.allCases.count == 2)
        #expect(MultidayPreset.allCases.contains(.thisWeek))
        #expect(MultidayPreset.allCases.contains(.nextWeek))
    }

    // MARK: - This Week with Sunday Start

    @Test func testThisWeekWithSundayStartFromMidWeek() {
        // Wednesday, January 8, 2026
        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        // Should be Sunday Jan 4 - Saturday Jan 10
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 4))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 10))
    }

    @Test func testThisWeekWithSundayStartFromSunday() {
        // Sunday, January 4, 2026
        let today = makeDate(year: 2026, month: 1, day: 4)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 4))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 10))
    }

    @Test func testThisWeekWithSundayStartFromSaturday() {
        // Saturday, January 10, 2026
        let today = makeDate(year: 2026, month: 1, day: 10)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 4))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 10))
    }

    // MARK: - This Week with Monday Start

    @Test func testThisWeekWithMondayStartFromMidWeek() {
        // Wednesday, January 8, 2026
        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .monday
        )

        #expect(range != nil)
        // Should be Monday Jan 5 - Sunday Jan 11
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 5))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 11))
    }

    @Test func testThisWeekWithMondayStartFromMonday() {
        // Monday, January 5, 2026
        let today = makeDate(year: 2026, month: 1, day: 5)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .monday
        )

        #expect(range != nil)
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 5))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 11))
    }

    @Test func testThisWeekWithMondayStartFromSunday() {
        // Sunday, January 11, 2026
        let today = makeDate(year: 2026, month: 1, day: 11)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .monday
        )

        #expect(range != nil)
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 5))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 11))
    }

    // MARK: - Next Week Tests

    @Test func testNextWeekWithSundayStart() {
        // Wednesday, January 8, 2026
        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.nextWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        // Next week: Sunday Jan 11 - Saturday Jan 17
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 11))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 17))
    }

    @Test func testNextWeekWithMondayStart() {
        // Wednesday, January 8, 2026
        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.nextWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .monday
        )

        #expect(range != nil)
        // Next week: Monday Jan 12 - Sunday Jan 18
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 12))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 18))
    }

    // MARK: - Week Span Verification

    @Test func testThisWeekSpansSevenDays() {
        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        let days = testCalendar.dateComponents([.day], from: range!.startDate, to: range!.endDate).day
        #expect(days == 6) // 6 days difference = 7 days total (inclusive)
    }

    @Test func testNextWeekSpansSevenDays() {
        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.nextWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .monday
        )

        #expect(range != nil)
        let days = testCalendar.dateComponents([.day], from: range!.startDate, to: range!.endDate).day
        #expect(days == 6)
    }

    // MARK: - Cross-Boundary Tests

    @Test func testThisWeekCrossesMonthBoundary() {
        // Friday, January 30, 2026
        let today = makeDate(year: 2026, month: 1, day: 30)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        // Week should be Sunday Jan 25 - Saturday Jan 31
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 25))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 31))
    }

    @Test func testNextWeekCrossesMonthBoundary() {
        // Friday, January 30, 2026
        let today = makeDate(year: 2026, month: 1, day: 30)
        let range = MultidayPreset.nextWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        // Next week: Sunday Feb 1 - Saturday Feb 7
        #expect(range?.startDate == makeDate(year: 2026, month: 2, day: 1))
        #expect(range?.endDate == makeDate(year: 2026, month: 2, day: 7))
    }

    @Test func testThisWeekCrossesYearBoundary() {
        // Wednesday, December 30, 2025
        let today = makeDate(year: 2025, month: 12, day: 30)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        // Week should be Sunday Dec 28 - Saturday Jan 3
        #expect(range?.startDate == makeDate(year: 2025, month: 12, day: 28))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 3))
    }

    @Test func testNextWeekCrossesYearBoundary() {
        // Wednesday, December 30, 2025
        let today = makeDate(year: 2025, month: 12, day: 30)
        let range = MultidayPreset.nextWeek.dateRange(
            from: today,
            calendar: testCalendar,
            firstWeekday: .sunday
        )

        #expect(range != nil)
        // Next week: Sunday Jan 4 - Saturday Jan 10
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 4))
        #expect(range?.endDate == makeDate(year: 2026, month: 1, day: 10))
    }

    // MARK: - System Default First Weekday

    @Test func testThisWeekWithSystemDefault() {
        // Use a calendar with Sunday as first weekday
        var sundayCalendar = testCalendar
        sundayCalendar.firstWeekday = 1

        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: sundayCalendar,
            firstWeekday: .systemDefault
        )

        #expect(range != nil)
        // Should use Sunday as first day
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 4))
    }

    @Test func testThisWeekWithSystemDefaultMonday() {
        // Use a calendar with Monday as first weekday (common in Europe)
        var mondayCalendar = testCalendar
        mondayCalendar.firstWeekday = 2

        let today = makeDate(year: 2026, month: 1, day: 8)
        let range = MultidayPreset.thisWeek.dateRange(
            from: today,
            calendar: mondayCalendar,
            firstWeekday: .systemDefault
        )

        #expect(range != nil)
        // Should use Monday as first day
        #expect(range?.startDate == makeDate(year: 2026, month: 1, day: 5))
    }
}
