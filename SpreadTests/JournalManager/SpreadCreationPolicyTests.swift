import Foundation
import Testing
@testable import Spread

struct SpreadCreationPolicyTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    /// Wednesday, January 15, 2026
    private static var testToday: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    private static func makePolicy(today: Date = testToday) -> StandardCreationPolicy {
        StandardCreationPolicy(today: today, firstWeekday: .sunday)
    }

    // MARK: - Year Period Tests

    /// Conditions: Today is Jan 15, 2026; request a year spread for 2026 with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testYearSpreadCanBeCreatedForPresentYear() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // January 15, 2026 - same year as today
        let result = policy.canCreateSpread(
            period: .year,
            date: Self.testToday,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; request a year spread for 2027 with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testYearSpreadCanBeCreatedForFutureYear() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // January 1, 2027 - future year
        let futureDate = calendar.date(from: .init(year: 2027, month: 1, day: 1))!

        let result = policy.canCreateSpread(
            period: .year,
            date: futureDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; request a year spread for 2025 with no existing spread.
    /// Expected: Policy denies creation.
    @Test func testYearSpreadCannotBeCreatedForPastYear() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // January 1, 2025 - past year
        let pastDate = calendar.date(from: .init(year: 2025, month: 1, day: 1))!

        let result = policy.canCreateSpread(
            period: .year,
            date: pastDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(!result)
    }

    // MARK: - Month Period Tests

    /// Conditions: Today is Jan 15, 2026; request a month spread for January 2026 with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testMonthSpreadCanBeCreatedForPresentMonth() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // January 15, 2026 - same month as today
        let result = policy.canCreateSpread(
            period: .month,
            date: Self.testToday,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; request a month spread for February 2026 with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testMonthSpreadCanBeCreatedForFutureMonth() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // February 1, 2026 - future month
        let futureDate = calendar.date(from: .init(year: 2026, month: 2, day: 1))!

        let result = policy.canCreateSpread(
            period: .month,
            date: futureDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; request a month spread for December 2025 with no existing spread.
    /// Expected: Policy denies creation.
    @Test func testMonthSpreadCannotBeCreatedForPastMonth() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // December 1, 2025 - past month
        let pastDate = calendar.date(from: .init(year: 2025, month: 12, day: 1))!

        let result = policy.canCreateSpread(
            period: .month,
            date: pastDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(!result)
    }

    // MARK: - Day Period Tests

    /// Conditions: Today is Jan 15, 2026; request a day spread for the same date with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testDaySpreadCanBeCreatedForToday() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        let result = policy.canCreateSpread(
            period: .day,
            date: Self.testToday,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; request a day spread for Jan 16, 2026 with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testDaySpreadCanBeCreatedForFutureDay() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // January 16, 2026 - tomorrow
        let futureDate = calendar.date(from: .init(year: 2026, month: 1, day: 16))!

        let result = policy.canCreateSpread(
            period: .day,
            date: futureDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; request a day spread for Jan 14, 2026 with no existing spread.
    /// Expected: Policy denies creation.
    @Test func testDaySpreadCannotBeCreatedForYesterday() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // January 14, 2026 - yesterday
        let pastDate = calendar.date(from: .init(year: 2026, month: 1, day: 14))!

        let result = policy.canCreateSpread(
            period: .day,
            date: pastDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(!result)
    }

    // MARK: - Multiday Period Tests

    /// Conditions: Today is Jan 15, 2026; start Jan 12 within the current week, end Jan 18, no existing spread.
    /// Expected: Policy allows multiday creation.
    @Test func testMultidaySpreadCanBeCreatedWithStartInCurrentWeek() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // Today is Wednesday Jan 15, 2026 (week starts Sunday Jan 11)
        // Start on Monday Jan 12 (within current week but before today)
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 12))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 18))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; start on Sunday Jan 11 (current week start), end Jan 17.
    /// Expected: Policy allows multiday creation.
    @Test func testMultidaySpreadCanBeCreatedWithStartOnSundayOfCurrentWeek() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // Today is Wednesday Jan 15, 2026 (week starts Sunday Jan 11)
        // Start on Sunday Jan 11 (first day of current week)
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 11))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 17))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; start Jan 10 before the current week, end Jan 17.
    /// Expected: Policy denies multiday creation.
    @Test func testMultidaySpreadCannotBeCreatedWithStartBeforeCurrentWeek() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // Today is Wednesday Jan 15, 2026 (week starts Sunday Jan 11)
        // Start on Saturday Jan 10 (before current week)
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 10))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 17))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(!result)
    }

    /// Conditions: Today is Jan 15, 2026; start Jan 18 next week, end Jan 24, no existing spread.
    /// Expected: Policy allows multiday creation.
    @Test func testMultidaySpreadCanBeCreatedWithFutureStartDate() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // Start next week
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 18))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 24))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 15, 2026; start Jan 5 and end Jan 10 entirely in the past.
    /// Expected: Policy denies multiday creation.
    @Test func testMultidaySpreadCannotBeCreatedWithEndDateInPast() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // Today is Wednesday Jan 15, 2026
        // Entire range in the past
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 5))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 10))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(!result)
    }

    /// Conditions: Today is Jan 15, 2026; start Jan 11 within current week, end today.
    /// Expected: Policy allows multiday creation.
    @Test func testMultidaySpreadCanBeCreatedWithEndDateToday() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        // Today is Wednesday Jan 15, 2026 (week starts Sunday Jan 11)
        // Start in past within current week, end on today
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 11))!
        let endDate = Self.testToday

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    // MARK: - Multiday with Different FirstWeekday Tests

    /// Conditions: First weekday is Monday; today is Jan 15, 2026; start Jan 11 (Sunday) and end Jan 17.
    /// Expected: Policy denies multiday creation because start is before the current week.
    @Test func testMultidaySpreadRespectsFirstWeekdayMonday() {
        // Today is Wednesday Jan 15, 2026
        // With Monday as first weekday, current week starts Monday Jan 13
        let policy = StandardCreationPolicy(today: Self.testToday, firstWeekday: .monday)
        let calendar = Self.testCalendar

        // Sunday Jan 11 is NOT within current week when first weekday is Monday
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 11))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 17))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(!result)
    }

    /// Conditions: First weekday is Monday; today is Jan 15, 2026; start Jan 13 (Monday) and end Jan 19.
    /// Expected: Policy allows multiday creation.
    @Test func testMultidaySpreadRespectsFirstWeekdayMondayAllowsWithinWeek() {
        // Today is Wednesday Jan 15, 2026
        // With Monday as first weekday, current week starts Monday Jan 13
        let policy = StandardCreationPolicy(today: Self.testToday, firstWeekday: .monday)
        let calendar = Self.testCalendar

        // Monday Jan 13 is within current week when first weekday is Monday
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 19))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    // MARK: - Duplicate Prevention Tests

    /// Conditions: Request a year spread for today with spreadExists set to true.
    /// Expected: Policy denies creation.
    @Test func testCannotCreateDuplicateYearSpread() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        let result = policy.canCreateSpread(
            period: .year,
            date: Self.testToday,
            spreadExists: true,
            calendar: calendar
        )

        #expect(!result)
    }

    /// Conditions: Request a month spread for today with spreadExists set to true.
    /// Expected: Policy denies creation.
    @Test func testCannotCreateDuplicateMonthSpread() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        let result = policy.canCreateSpread(
            period: .month,
            date: Self.testToday,
            spreadExists: true,
            calendar: calendar
        )

        #expect(!result)
    }

    /// Conditions: Request a day spread for today with spreadExists set to true.
    /// Expected: Policy denies creation.
    @Test func testCannotCreateDuplicateDaySpread() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        let result = policy.canCreateSpread(
            period: .day,
            date: Self.testToday,
            spreadExists: true,
            calendar: calendar
        )

        #expect(!result)
    }

    /// Conditions: Request a multiday spread with spreadExists set to true.
    /// Expected: Policy denies creation.
    @Test func testCannotCreateDuplicateMultidaySpread() {
        let policy = Self.makePolicy()
        let calendar = Self.testCalendar

        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 18))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 24))!

        let result = policy.canCreateMultidaySpread(
            startDate: startDate,
            endDate: endDate,
            spreadExists: true,
            calendar: calendar
        )

        #expect(!result)
    }

    // MARK: - Edge Case Tests

    /// Conditions: Today is Jan 31, 2026; request a day spread for the same date with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testDaySpreadForTodayAtEndOfMonth() {
        let calendar = Self.testCalendar
        // January 31, 2026
        let today = calendar.date(from: .init(year: 2026, month: 1, day: 31))!
        let policy = StandardCreationPolicy(today: today, firstWeekday: .sunday)

        let result = policy.canCreateSpread(
            period: .day,
            date: today,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Dec 31, 2026; request a month spread for Jan 2027 with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testMonthSpreadAtYearBoundary() {
        let calendar = Self.testCalendar
        // December 31, 2026
        let today = calendar.date(from: .init(year: 2026, month: 12, day: 31))!
        let policy = StandardCreationPolicy(today: today, firstWeekday: .sunday)

        // Can create for January 2027 (future)
        let futureDate = calendar.date(from: .init(year: 2027, month: 1, day: 1))!
        let result = policy.canCreateSpread(
            period: .month,
            date: futureDate,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }

    /// Conditions: Today is Jan 1, 2026; request a year spread for the same date with no existing spread.
    /// Expected: Policy allows creation.
    @Test func testCanCreateSpreadForFirstDayOfYear() {
        let calendar = Self.testCalendar
        // January 1, 2026
        let today = calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        let policy = StandardCreationPolicy(today: today, firstWeekday: .sunday)

        let result = policy.canCreateSpread(
            period: .year,
            date: today,
            spreadExists: false,
            calendar: calendar
        )

        #expect(result)
    }
}
