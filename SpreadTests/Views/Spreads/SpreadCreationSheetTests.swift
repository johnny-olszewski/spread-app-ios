import Foundation
import Testing
@testable import Spread

struct SpreadCreationSheetTests {

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

    private static func makeConfiguration(
        today: Date = testToday,
        firstWeekday: FirstWeekday = .sunday,
        existingSpreads: [DataModel.Spread] = []
    ) -> SpreadCreationConfiguration {
        SpreadCreationConfiguration(
            calendar: testCalendar,
            today: today,
            firstWeekday: firstWeekday,
            existingSpreads: existingSpreads
        )
    }

    // MARK: - Period Description Tests

    /// Conditions: Period is year.
    /// Expected: Description indicates year coverage.
    @Test func testYearPeriodDescription() {
        let description = SpreadCreationConfiguration.periodDescription(for: .year)

        #expect(description.contains("year"))
    }

    /// Conditions: Period is month.
    /// Expected: Description indicates month coverage.
    @Test func testMonthPeriodDescription() {
        let description = SpreadCreationConfiguration.periodDescription(for: .month)

        #expect(description.contains("month"))
    }

    /// Conditions: Period is day.
    /// Expected: Description indicates day coverage.
    @Test func testDayPeriodDescription() {
        let description = SpreadCreationConfiguration.periodDescription(for: .day)

        #expect(description.contains("day"))
    }

    /// Conditions: Period is multiday.
    /// Expected: Description indicates range coverage.
    @Test func testMultidayPeriodDescription() {
        let description = SpreadCreationConfiguration.periodDescription(for: .multiday)

        #expect(description.contains("range") || description.contains("multiday") || description.contains("days"))
    }

    // MARK: - Year/Month/Day Validation Tests

    /// Conditions: Today is Jan 15, 2026; request year spread for 2026 with no existing spreads.
    /// Expected: Creation is allowed.
    @Test func testCanCreateYearSpreadForPresentYear() {
        let config = Self.makeConfiguration()
        let date = Self.testToday

        let result = config.canCreate(period: .year, date: date)

        #expect(result.isValid)
    }

    /// Conditions: Today is Jan 15, 2026; request year spread for 2027 with no existing spreads.
    /// Expected: Creation is allowed.
    @Test func testCanCreateYearSpreadForFutureYear() {
        let config = Self.makeConfiguration()
        let date = Self.testCalendar.date(from: .init(year: 2027, month: 1, day: 1))!

        let result = config.canCreate(period: .year, date: date)

        #expect(result.isValid)
    }

    /// Conditions: Today is Jan 15, 2026; request year spread for 2025.
    /// Expected: Creation is denied with past date error.
    @Test func testCannotCreateYearSpreadForPastYear() {
        let config = Self.makeConfiguration()
        let date = Self.testCalendar.date(from: .init(year: 2025, month: 1, day: 1))!

        let result = config.canCreate(period: .year, date: date)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    /// Conditions: Today is Jan 15, 2026; request month spread for January 2026 with no existing spreads.
    /// Expected: Creation is allowed.
    @Test func testCanCreateMonthSpreadForPresentMonth() {
        let config = Self.makeConfiguration()
        let date = Self.testToday

        let result = config.canCreate(period: .month, date: date)

        #expect(result.isValid)
    }

    /// Conditions: Today is Jan 15, 2026; request month spread for December 2025.
    /// Expected: Creation is denied with past date error.
    @Test func testCannotCreateMonthSpreadForPastMonth() {
        let config = Self.makeConfiguration()
        let date = Self.testCalendar.date(from: .init(year: 2025, month: 12, day: 1))!

        let result = config.canCreate(period: .month, date: date)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    /// Conditions: Today is Jan 15, 2026; request day spread for today with no existing spreads.
    /// Expected: Creation is allowed.
    @Test func testCanCreateDaySpreadForToday() {
        let config = Self.makeConfiguration()
        let date = Self.testToday

        let result = config.canCreate(period: .day, date: date)

        #expect(result.isValid)
    }

    /// Conditions: Today is Jan 15, 2026; request day spread for Jan 14, 2026.
    /// Expected: Creation is denied with past date error.
    @Test func testCannotCreateDaySpreadForYesterday() {
        let config = Self.makeConfiguration()
        let date = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 14))!

        let result = config.canCreate(period: .day, date: date)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    // MARK: - Duplicate Detection Tests

    /// Conditions: Year spread for 2026 already exists; request year spread for 2026.
    /// Expected: Creation is denied with duplicate error.
    @Test func testCannotCreateDuplicateYearSpread() {
        let existingSpread = DataModel.Spread(period: .year, date: Self.testToday, calendar: Self.testCalendar)
        let config = Self.makeConfiguration(existingSpreads: [existingSpread])

        let result = config.canCreate(period: .year, date: Self.testToday)

        #expect(!result.isValid)
        #expect(result.error == .duplicate)
    }

    /// Conditions: Month spread for January 2026 already exists; request month spread for January 2026.
    /// Expected: Creation is denied with duplicate error.
    @Test func testCannotCreateDuplicateMonthSpread() {
        let existingSpread = DataModel.Spread(period: .month, date: Self.testToday, calendar: Self.testCalendar)
        let config = Self.makeConfiguration(existingSpreads: [existingSpread])

        let result = config.canCreate(period: .month, date: Self.testToday)

        #expect(!result.isValid)
        #expect(result.error == .duplicate)
    }

    /// Conditions: Day spread for Jan 15, 2026 already exists; request day spread for Jan 15, 2026.
    /// Expected: Creation is denied with duplicate error.
    @Test func testCannotCreateDuplicateDaySpread() {
        let existingSpread = DataModel.Spread(period: .day, date: Self.testToday, calendar: Self.testCalendar)
        let config = Self.makeConfiguration(existingSpreads: [existingSpread])

        let result = config.canCreate(period: .day, date: Self.testToday)

        #expect(!result.isValid)
        #expect(result.error == .duplicate)
    }

    // MARK: - Multiday Validation Tests

    /// Conditions: Today is Jan 15, 2026; request multiday from Jan 12 (within current week) to Jan 18.
    /// Expected: Creation is allowed.
    @Test func testCanCreateMultidayWithStartInCurrentWeek() {
        let config = Self.makeConfiguration()
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 12))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 18))!

        let result = config.canCreateMultiday(startDate: startDate, endDate: endDate)

        #expect(result.isValid)
    }

    /// Conditions: Today is Jan 15, 2026; request multiday from Jan 10 (before current week) to Jan 17.
    /// Expected: Creation is denied with past date error.
    @Test func testCannotCreateMultidayWithStartBeforeCurrentWeek() {
        let config = Self.makeConfiguration()
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 10))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 17))!

        let result = config.canCreateMultiday(startDate: startDate, endDate: endDate)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    /// Conditions: Today is Jan 15, 2026; request multiday from Jan 5 to Jan 10 (entirely in past).
    /// Expected: Creation is denied with past date error.
    @Test func testCannotCreateMultidayWithEndDateInPast() {
        let config = Self.makeConfiguration()
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 5))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 10))!

        let result = config.canCreateMultiday(startDate: startDate, endDate: endDate)

        #expect(!result.isValid)
        #expect(result.error == .pastDate)
    }

    /// Conditions: Request multiday with end date before start date.
    /// Expected: Creation is denied with invalid range error.
    @Test func testCannotCreateMultidayWithEndBeforeStart() {
        let config = Self.makeConfiguration()
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 20))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 18))!

        let result = config.canCreateMultiday(startDate: startDate, endDate: endDate)

        #expect(!result.isValid)
        #expect(result.error == .invalidRange)
    }

    // MARK: - Multiday Preset Tests

    /// Conditions: Today is Jan 15, 2026 (Wednesday); first weekday is Sunday.
    /// Expected: "This Week" preset returns Jan 11 (Sunday) to Jan 17 (Saturday).
    @Test func testThisWeekPresetWithSundayFirstWeekday() {
        let config = Self.makeConfiguration(firstWeekday: .sunday)

        guard let range = config.dateRange(for: .thisWeek) else {
            Issue.record("Failed to compute This Week range")
            return
        }

        let startComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.startDate)
        let endComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.endDate)

        #expect(startComponents.day == 11)
        #expect(startComponents.month == 1)
        #expect(endComponents.day == 17)
        #expect(endComponents.month == 1)
    }

    /// Conditions: Today is Jan 15, 2026 (Thursday); first weekday is Monday.
    /// Expected: "This Week" preset returns Jan 12 (Monday) to Jan 18 (Sunday).
    @Test func testThisWeekPresetWithMondayFirstWeekday() {
        let config = Self.makeConfiguration(firstWeekday: .monday)

        guard let range = config.dateRange(for: .thisWeek) else {
            Issue.record("Failed to compute This Week range")
            return
        }

        let startComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.startDate)
        let endComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.endDate)

        #expect(startComponents.day == 12)
        #expect(startComponents.month == 1)
        #expect(endComponents.day == 18)
        #expect(endComponents.month == 1)
    }

    /// Conditions: Today is Jan 15, 2026 (Wednesday); first weekday is Sunday.
    /// Expected: "Next Week" preset returns Jan 18 (Sunday) to Jan 24 (Saturday).
    @Test func testNextWeekPresetWithSundayFirstWeekday() {
        let config = Self.makeConfiguration(firstWeekday: .sunday)

        guard let range = config.dateRange(for: .nextWeek) else {
            Issue.record("Failed to compute Next Week range")
            return
        }

        let startComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.startDate)
        let endComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.endDate)

        #expect(startComponents.day == 18)
        #expect(startComponents.month == 1)
        #expect(endComponents.day == 24)
        #expect(endComponents.month == 1)
    }

    /// Conditions: Today is Jan 15, 2026 (Thursday); first weekday is Monday.
    /// Expected: "Next Week" preset returns Jan 19 (Monday) to Jan 25 (Sunday).
    @Test func testNextWeekPresetWithMondayFirstWeekday() {
        let config = Self.makeConfiguration(firstWeekday: .monday)

        guard let range = config.dateRange(for: .nextWeek) else {
            Issue.record("Failed to compute Next Week range")
            return
        }

        let startComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.startDate)
        let endComponents = Self.testCalendar.dateComponents([.year, .month, .day], from: range.endDate)

        #expect(startComponents.day == 19)
        #expect(startComponents.month == 1)
        #expect(endComponents.day == 25)
        #expect(endComponents.month == 1)
    }

    // MARK: - Multiday Duplicate Detection Tests

    /// Conditions: Multiday spread with same range already exists.
    /// Expected: Creation is denied with duplicate error.
    @Test func testCannotCreateDuplicateMultidaySpread() {
        let startDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 18))!
        let endDate = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 24))!
        let existingSpread = DataModel.Spread(
            startDate: startDate,
            endDate: endDate,
            calendar: Self.testCalendar
        )
        let config = Self.makeConfiguration(existingSpreads: [existingSpread])

        let result = config.canCreateMultiday(startDate: startDate, endDate: endDate)

        #expect(!result.isValid)
        #expect(result.error == .duplicate)
    }

    // MARK: - Date Range Tests

    /// Conditions: Period is year.
    /// Expected: Minimum date is normalized to start of current year.
    @Test func testMinimumDateForYear() {
        let config = Self.makeConfiguration()

        let minDate = config.minimumDate(for: .year)
        let components = Self.testCalendar.dateComponents([.year, .month, .day], from: minDate)

        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    /// Conditions: Period is month.
    /// Expected: Minimum date is normalized to start of current month.
    @Test func testMinimumDateForMonth() {
        let config = Self.makeConfiguration()

        let minDate = config.minimumDate(for: .month)
        let components = Self.testCalendar.dateComponents([.year, .month, .day], from: minDate)

        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    /// Conditions: Period is day.
    /// Expected: Minimum date is today.
    @Test func testMinimumDateForDay() {
        let config = Self.makeConfiguration()

        let minDate = config.minimumDate(for: .day)
        let components = Self.testCalendar.dateComponents([.year, .month, .day], from: minDate)

        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 15)
    }

    // MARK: - Validation Message Tests

    /// Conditions: Validation error is pastDate.
    /// Expected: Message mentions past or future.
    @Test func testValidationMessageForPastDate() {
        let message = SpreadCreationError.pastDate.message

        #expect(message.lowercased().contains("past") || message.lowercased().contains("future"))
    }

    /// Conditions: Validation error is duplicate.
    /// Expected: Message mentions exists or already.
    @Test func testValidationMessageForDuplicate() {
        let message = SpreadCreationError.duplicate.message

        #expect(message.lowercased().contains("exist") || message.lowercased().contains("already"))
    }

    /// Conditions: Validation error is invalidRange.
    /// Expected: Message mentions end, start, or range.
    @Test func testValidationMessageForInvalidRange() {
        let message = SpreadCreationError.invalidRange.message

        #expect(message.lowercased().contains("end") || message.lowercased().contains("start") || message.lowercased().contains("range"))
    }
}
