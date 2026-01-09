import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.DateComponents
import struct Foundation.TimeZone
import Testing
@testable import Spread

struct PeriodTests {

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

    // MARK: - Scope Guard: No Week Period

    @Test func testWeekPeriodDoesNotExist() {
        let allCases = Period.allCases
        let hasWeek = allCases.contains { $0.rawValue == "week" }
        #expect(!hasWeek, "Week period must not exist per spec Non-Goals")
    }

    @Test func testPeriodCasesAreYearMonthDayMultiday() {
        let cases = Period.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.year))
        #expect(cases.contains(.month))
        #expect(cases.contains(.day))
        #expect(cases.contains(.multiday))
    }

    // MARK: - Display Name Tests

    @Test func testYearDisplayName() {
        #expect(Period.year.displayName == "Year")
    }

    @Test func testMonthDisplayName() {
        #expect(Period.month.displayName == "Month")
    }

    @Test func testDayDisplayName() {
        #expect(Period.day.displayName == "Day")
    }

    @Test func testMultidayDisplayName() {
        #expect(Period.multiday.displayName == "Multiday")
    }

    // MARK: - Calendar Component Tests

    @Test func testYearCalendarComponent() {
        #expect(Period.year.calendarComponent == .year)
    }

    @Test func testMonthCalendarComponent() {
        #expect(Period.month.calendarComponent == .month)
    }

    @Test func testDayCalendarComponent() {
        #expect(Period.day.calendarComponent == .day)
    }

    @Test func testMultidayCalendarComponentIsNil() {
        #expect(Period.multiday.calendarComponent == nil)
    }

    // MARK: - Task Assignment Tests

    @Test func testYearCanHaveTasksAssigned() {
        #expect(Period.year.canHaveTasksAssigned == true)
    }

    @Test func testMonthCanHaveTasksAssigned() {
        #expect(Period.month.canHaveTasksAssigned == true)
    }

    @Test func testDayCanHaveTasksAssigned() {
        #expect(Period.day.canHaveTasksAssigned == true)
    }

    @Test func testMultidayCannotHaveTasksAssigned() {
        #expect(Period.multiday.canHaveTasksAssigned == false)
    }

    // MARK: - Child Period Tests

    @Test func testYearChildPeriodIsMonth() {
        #expect(Period.year.childPeriod == .month)
    }

    @Test func testMonthChildPeriodIsDay() {
        #expect(Period.month.childPeriod == .day)
    }

    @Test func testDayChildPeriodIsNil() {
        #expect(Period.day.childPeriod == nil)
    }

    @Test func testMultidayChildPeriodIsNil() {
        #expect(Period.multiday.childPeriod == nil)
    }

    // MARK: - Parent Period Tests

    @Test func testYearParentPeriodIsNil() {
        #expect(Period.year.parentPeriod == nil)
    }

    @Test func testMonthParentPeriodIsYear() {
        #expect(Period.month.parentPeriod == .year)
    }

    @Test func testDayParentPeriodIsMonth() {
        #expect(Period.day.parentPeriod == .month)
    }

    @Test func testMultidayParentPeriodIsNil() {
        #expect(Period.multiday.parentPeriod == nil)
    }

    // MARK: - Period Hierarchy Consistency

    @Test func testPeriodHierarchyIsConsistent() {
        // Verify parent/child relationships are bidirectional
        #expect(Period.month.parentPeriod?.childPeriod == .month)
        #expect(Period.day.parentPeriod?.childPeriod == .day)
    }

    // MARK: - Date Normalization: Year

    @Test func testYearNormalizationFromMidYear() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let normalized = Period.year.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    @Test func testYearNormalizationFromDecember() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        let normalized = Period.year.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    @Test func testYearNormalizationFromJanuary() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        let normalized = Period.year.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    // MARK: - Date Normalization: Month

    @Test func testMonthNormalizationFromMidMonth() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let normalized = Period.month.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 1)
        #expect(normalized == expected)
    }

    @Test func testMonthNormalizationFromLastDay() {
        let date = makeDate(year: 2026, month: 1, day: 31)
        let normalized = Period.month.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    @Test func testMonthNormalizationFromFirstDay() {
        let date = makeDate(year: 2026, month: 3, day: 1)
        let normalized = Period.month.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 3, day: 1)
        #expect(normalized == expected)
    }

    // MARK: - Date Normalization: Day

    @Test func testDayNormalizationRemovesTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 14
        components.minute = 30
        let date = testCalendar.date(from: components)!

        let normalized = Period.day.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15)
        #expect(normalized == expected)
    }

    @Test func testDayNormalizationPreservesDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let normalized = Period.day.normalizeDate(date, calendar: testCalendar)

        #expect(normalized == date)
    }

    // MARK: - Date Normalization: Multiday

    @Test func testMultidayNormalizationBehavesLikeDay() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 14
        components.minute = 30
        let date = testCalendar.date(from: components)!

        let normalized = Period.multiday.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 15)
        #expect(normalized == expected)
    }

    // MARK: - Raw Value Tests

    @Test func testYearRawValue() {
        #expect(Period.year.rawValue == "year")
    }

    @Test func testMonthRawValue() {
        #expect(Period.month.rawValue == "month")
    }

    @Test func testDayRawValue() {
        #expect(Period.day.rawValue == "day")
    }

    @Test func testMultidayRawValue() {
        #expect(Period.multiday.rawValue == "multiday")
    }

    @Test func testInitFromRawValue() {
        #expect(Period(rawValue: "year") == .year)
        #expect(Period(rawValue: "month") == .month)
        #expect(Period(rawValue: "day") == .day)
        #expect(Period(rawValue: "multiday") == .multiday)
        #expect(Period(rawValue: "week") == nil)
        #expect(Period(rawValue: "invalid") == nil)
    }
}
