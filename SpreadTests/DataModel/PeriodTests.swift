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

    /// Conditions: Check Period.allCases for "week".
    /// Expected: Week period must not exist per spec Non-Goals.
    @Test func testWeekPeriodDoesNotExist() {
        let allCases = Period.allCases
        let hasWeek = allCases.contains { $0.rawValue == "week" }
        #expect(!hasWeek, "Week period must not exist per spec Non-Goals")
    }

    /// Conditions: Check Period.allCases.
    /// Expected: Should contain exactly 4 cases: year, month, day, multiday.
    @Test func testPeriodCasesAreYearMonthDayMultiday() {
        let cases = Period.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.year))
        #expect(cases.contains(.month))
        #expect(cases.contains(.day))
        #expect(cases.contains(.multiday))
    }

    // MARK: - Display Name Tests

    /// Conditions: Access year displayName.
    /// Expected: Should return "Year".
    @Test func testYearDisplayName() {
        #expect(Period.year.displayName == "Year")
    }

    /// Conditions: Access month displayName.
    /// Expected: Should return "Month".
    @Test func testMonthDisplayName() {
        #expect(Period.month.displayName == "Month")
    }

    /// Conditions: Access day displayName.
    /// Expected: Should return "Day".
    @Test func testDayDisplayName() {
        #expect(Period.day.displayName == "Day")
    }

    /// Conditions: Access multiday displayName.
    /// Expected: Should return "Multiday".
    @Test func testMultidayDisplayName() {
        #expect(Period.multiday.displayName == "Multiday")
    }

    // MARK: - Calendar Component Tests

    /// Conditions: Access year calendarComponent.
    /// Expected: Should return .year.
    @Test func testYearCalendarComponent() {
        #expect(Period.year.calendarComponent == .year)
    }

    /// Conditions: Access month calendarComponent.
    /// Expected: Should return .month.
    @Test func testMonthCalendarComponent() {
        #expect(Period.month.calendarComponent == .month)
    }

    /// Conditions: Access day calendarComponent.
    /// Expected: Should return .day.
    @Test func testDayCalendarComponent() {
        #expect(Period.day.calendarComponent == .day)
    }

    /// Conditions: Access multiday calendarComponent.
    /// Expected: Should return nil (multiday has no single calendar component).
    @Test func testMultidayCalendarComponentIsNil() {
        #expect(Period.multiday.calendarComponent == nil)
    }

    // MARK: - Task Assignment Tests

    /// Conditions: Check if year period can have tasks assigned.
    /// Expected: Should return true.
    @Test func testYearCanHaveTasksAssigned() {
        #expect(Period.year.canHaveTasksAssigned == true)
    }

    /// Conditions: Check if month period can have tasks assigned.
    /// Expected: Should return true.
    @Test func testMonthCanHaveTasksAssigned() {
        #expect(Period.month.canHaveTasksAssigned == true)
    }

    /// Conditions: Check if day period can have tasks assigned.
    /// Expected: Should return true.
    @Test func testDayCanHaveTasksAssigned() {
        #expect(Period.day.canHaveTasksAssigned == true)
    }

    /// Conditions: Check if multiday period can have tasks assigned.
    /// Expected: Should return false (tasks aggregate by date range, not assigned directly).
    @Test func testMultidayCannotHaveTasksAssigned() {
        #expect(Period.multiday.canHaveTasksAssigned == false)
    }

    // MARK: - Child Period Tests

    /// Conditions: Access year childPeriod.
    /// Expected: Should return month.
    @Test func testYearChildPeriodIsMonth() {
        #expect(Period.year.childPeriod == .month)
    }

    /// Conditions: Access month childPeriod.
    /// Expected: Should return day.
    @Test func testMonthChildPeriodIsDay() {
        #expect(Period.month.childPeriod == .day)
    }

    /// Conditions: Access day childPeriod.
    /// Expected: Should return nil (day is the finest granularity).
    @Test func testDayChildPeriodIsNil() {
        #expect(Period.day.childPeriod == nil)
    }

    /// Conditions: Access multiday childPeriod.
    /// Expected: Should return nil (multiday is outside the hierarchy).
    @Test func testMultidayChildPeriodIsNil() {
        #expect(Period.multiday.childPeriod == nil)
    }

    // MARK: - Parent Period Tests

    /// Conditions: Access year parentPeriod.
    /// Expected: Should return nil (year is the coarsest granularity).
    @Test func testYearParentPeriodIsNil() {
        #expect(Period.year.parentPeriod == nil)
    }

    /// Conditions: Access month parentPeriod.
    /// Expected: Should return year.
    @Test func testMonthParentPeriodIsYear() {
        #expect(Period.month.parentPeriod == .year)
    }

    /// Conditions: Access day parentPeriod.
    /// Expected: Should return month.
    @Test func testDayParentPeriodIsMonth() {
        #expect(Period.day.parentPeriod == .month)
    }

    /// Conditions: Access multiday parentPeriod.
    /// Expected: Should return nil (multiday is outside the hierarchy).
    @Test func testMultidayParentPeriodIsNil() {
        #expect(Period.multiday.parentPeriod == nil)
    }

    // MARK: - Period Hierarchy Consistency

    /// Conditions: Verify parent/child relationship bidirectionality.
    /// Expected: parentPeriod.childPeriod should return back to original period.
    @Test func testPeriodHierarchyIsConsistent() {
        // Verify parent/child relationships are bidirectional
        #expect(Period.month.parentPeriod?.childPeriod == .month)
        #expect(Period.day.parentPeriod?.childPeriod == .day)
    }

    // MARK: - Date Normalization: Year

    /// Conditions: Date is June 15, 2026 (mid-year).
    /// Expected: Should normalize to January 1, 2026.
    @Test func testYearNormalizationFromMidYear() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let normalized = Period.year.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    /// Conditions: Date is December 31, 2026 (last day of year).
    /// Expected: Should normalize to January 1, 2026.
    @Test func testYearNormalizationFromDecember() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        let normalized = Period.year.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    /// Conditions: Date is already January 1, 2026.
    /// Expected: Should return same date.
    @Test func testYearNormalizationFromJanuary() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        let normalized = Period.year.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    // MARK: - Date Normalization: Month

    /// Conditions: Date is June 15, 2026 (mid-month).
    /// Expected: Should normalize to June 1, 2026.
    @Test func testMonthNormalizationFromMidMonth() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let normalized = Period.month.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 6, day: 1)
        #expect(normalized == expected)
    }

    /// Conditions: Date is January 31, 2026 (last day of month).
    /// Expected: Should normalize to January 1, 2026.
    @Test func testMonthNormalizationFromLastDay() {
        let date = makeDate(year: 2026, month: 1, day: 31)
        let normalized = Period.month.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 1, day: 1)
        #expect(normalized == expected)
    }

    /// Conditions: Date is already March 1, 2026 (first of month).
    /// Expected: Should return same date.
    @Test func testMonthNormalizationFromFirstDay() {
        let date = makeDate(year: 2026, month: 3, day: 1)
        let normalized = Period.month.normalizeDate(date, calendar: testCalendar)

        let expected = makeDate(year: 2026, month: 3, day: 1)
        #expect(normalized == expected)
    }

    // MARK: - Date Normalization: Day

    /// Conditions: Date has time component (14:30).
    /// Expected: Should normalize to start of day (midnight).
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

    /// Conditions: Date is already at midnight.
    /// Expected: Should return same date.
    @Test func testDayNormalizationPreservesDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let normalized = Period.day.normalizeDate(date, calendar: testCalendar)

        #expect(normalized == date)
    }

    // MARK: - Date Normalization: Multiday

    /// Conditions: Multiday period with date having time component.
    /// Expected: Should normalize to start of day (same as day normalization).
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

    /// Conditions: Access year rawValue.
    /// Expected: Should return "year".
    @Test func testYearRawValue() {
        #expect(Period.year.rawValue == "year")
    }

    /// Conditions: Access month rawValue.
    /// Expected: Should return "month".
    @Test func testMonthRawValue() {
        #expect(Period.month.rawValue == "month")
    }

    /// Conditions: Access day rawValue.
    /// Expected: Should return "day".
    @Test func testDayRawValue() {
        #expect(Period.day.rawValue == "day")
    }

    /// Conditions: Access multiday rawValue.
    /// Expected: Should return "multiday".
    @Test func testMultidayRawValue() {
        #expect(Period.multiday.rawValue == "multiday")
    }

    /// Conditions: Initialize Period from various raw values.
    /// Expected: Valid values should create periods; "week" and invalid should return nil.
    @Test func testInitFromRawValue() {
        #expect(Period(rawValue: "year") == .year)
        #expect(Period(rawValue: "month") == .month)
        #expect(Period(rawValue: "day") == .day)
        #expect(Period(rawValue: "multiday") == .multiday)
        #expect(Period(rawValue: "week") == nil)
        #expect(Period(rawValue: "invalid") == nil)
    }
}
