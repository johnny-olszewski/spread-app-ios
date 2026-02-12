import Foundation
import Testing
@testable import Spread

struct ConventionalSpreadServiceTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    /// January 15, 2026
    private static var testDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    /// February 20, 2026
    private static var differentMonthDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 2, day: 20))!
    }

    /// January 1, 2027
    private static var differentYearDate: Date {
        testCalendar.date(from: .init(year: 2027, month: 1, day: 1))!
    }

    private static func makeService() -> ConventionalSpreadService {
        ConventionalSpreadService(calendar: testCalendar)
    }

    private static func makeSpread(period: Period, date: Date) -> DataModel.Spread {
        DataModel.Spread(period: period, date: date, calendar: testCalendar)
    }

    private static func makeMultidaySpread(startDate: Date, endDate: Date) -> DataModel.Spread {
        DataModel.Spread(startDate: startDate, endDate: endDate, calendar: testCalendar)
    }

    private static func makeTask(date: Date, period: Period) -> DataModel.Task {
        DataModel.Task(title: "Test Task", date: date, period: period)
    }

    private static func makeNote(date: Date, period: Period) -> DataModel.Note {
        DataModel.Note(title: "Test Note", date: date, period: period)
    }

    // MARK: - Task Assignment: Exact Match Tests

    /// Conditions: A day-period task matches a day spread on the same date.
    /// Expected: Service returns the day spread.
    @Test func testTaskWithDayPeriodMatchesDaySpread() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [daySpread])

        #expect(result?.id == daySpread.id)
    }

    /// Conditions: A month-period task matches a month spread on the same date.
    /// Expected: Service returns the month spread.
    @Test func testTaskWithMonthPeriodMatchesMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .month)

        let result = service.findBestSpread(for: task, in: [monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    /// Conditions: A year-period task matches a year spread on the same date.
    /// Expected: Service returns the year spread.
    @Test func testTaskWithYearPeriodMatchesYearSpread() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .year)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result?.id == yearSpread.id)
    }

    // MARK: - Task Assignment: Fallback Tests (Finest to Coarsest)

    /// Conditions: A day-period task has no day spread, but a month spread exists for the date.
    /// Expected: Service falls back to the month spread.
    @Test func testTaskWithDayPeriodFallsBackToMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    /// Conditions: A day-period task has no day or month spread, but a year spread exists.
    /// Expected: Service falls back to the year spread.
    @Test func testTaskWithDayPeriodFallsBackToYearSpread() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result?.id == yearSpread.id)
    }

    /// Conditions: A month-period task has no month spread, but a year spread exists.
    /// Expected: Service falls back to the year spread.
    @Test func testTaskWithMonthPeriodFallsBackToYearSpread() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .month)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result?.id == yearSpread.id)
    }

    /// Conditions: A day-period task has matching day, month, and year spreads.
    /// Expected: Service selects the finest match (day spread).
    @Test func testTaskPrefersFinestMatchingSpread() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [yearSpread, monthSpread, daySpread])

        #expect(result?.id == daySpread.id)
    }

    /// Conditions: A month-period task has matching month and year spreads.
    /// Expected: Service selects the month spread over the year spread.
    @Test func testTaskWithMonthPeriodPrefersMonthOverYear() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .month)

        let result = service.findBestSpread(for: task, in: [yearSpread, monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    // MARK: - Task Assignment: No Match Tests

    /// Conditions: A task is evaluated with no spreads available.
    /// Expected: Service returns nil.
    @Test func testTaskReturnsNilWhenNoSpreadExists() {
        let service = Self.makeService()
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [])

        #expect(result == nil)
    }

    /// Conditions: A task date does not match any provided spread dates.
    /// Expected: Service returns nil.
    @Test func testTaskReturnsNilWhenNoMatchingDateSpreadExists() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.differentYearDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result == nil)
    }

    /// Conditions: Only a multiday spread exists for a task date.
    /// Expected: Service returns nil.
    @Test func testTaskReturnsNilWhenOnlyMultidaySpreadExists() {
        let service = Self.makeService()
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let multidaySpread = Self.makeMultidaySpread(startDate: startDate, endDate: endDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [multidaySpread])

        #expect(result == nil)
    }

    // MARK: - Task Assignment: Multiday Skipped Tests

    /// Conditions: Both a multiday spread and a matching day spread are available.
    /// Expected: Service returns the day spread.
    @Test func testMultidaySpreadIsSkippedInFavorOfDaySpread() {
        let service = Self.makeService()
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let multidaySpread = Self.makeMultidaySpread(startDate: startDate, endDate: endDate)
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [multidaySpread, daySpread])

        #expect(result?.id == daySpread.id)
    }

    // MARK: - Note Assignment Tests

    /// Conditions: A day-period note matches a day spread on the same date.
    /// Expected: Service returns the day spread.
    @Test func testNoteWithDayPeriodMatchesDaySpread() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let note = Self.makeNote(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: note, in: [daySpread])

        #expect(result?.id == daySpread.id)
    }

    /// Conditions: A day-period note has no day spread, but a month spread exists.
    /// Expected: Service falls back to the month spread.
    @Test func testNoteWithDayPeriodFallsBackToMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let note = Self.makeNote(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: note, in: [monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    /// Conditions: A note is evaluated with no spreads available.
    /// Expected: Service returns nil.
    @Test func testNoteReturnsNilWhenNoSpreadExists() {
        let service = Self.makeService()
        let note = Self.makeNote(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: note, in: [])

        #expect(result == nil)
    }

    // MARK: - Event Visibility: Year Spread Tests

    /// Conditions: An event's date falls within the year spread range.
    /// Expected: Event appears on the year spread.
    @Test func testEventAppearsOnYearSpreadWhenDateOverlaps() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )

        let result = service.eventAppearsOnSpread(event, spread: yearSpread)

        #expect(result == true)
    }

    /// Conditions: An event's dates are outside the year spread range.
    /// Expected: Event does not appear on the year spread.
    @Test func testEventDoesNotAppearOnYearSpreadWhenDateDoesNotOverlap() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.differentYearDate,
            endDate: Self.differentYearDate
        )

        let result = service.eventAppearsOnSpread(event, spread: yearSpread)

        #expect(result == false)
    }

    // MARK: - Event Visibility: Month Spread Tests

    /// Conditions: An event's date falls within the month spread range.
    /// Expected: Event appears on the month spread.
    @Test func testEventAppearsOnMonthSpreadWhenDateOverlaps() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )

        let result = service.eventAppearsOnSpread(event, spread: monthSpread)

        #expect(result == true)
    }

    /// Conditions: An event's dates are outside the month spread range.
    /// Expected: Event does not appear on the month spread.
    @Test func testEventDoesNotAppearOnMonthSpreadWhenDateDoesNotOverlap() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.differentMonthDate,
            endDate: Self.differentMonthDate
        )

        let result = service.eventAppearsOnSpread(event, spread: monthSpread)

        #expect(result == false)
    }

    // MARK: - Event Visibility: Day Spread Tests

    /// Conditions: An event's date matches the day spread date.
    /// Expected: Event appears on the day spread.
    @Test func testEventAppearsOnDaySpreadWhenDateOverlaps() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )

        let result = service.eventAppearsOnSpread(event, spread: daySpread)

        #expect(result == true)
    }

    /// Conditions: An event's date differs from the day spread date.
    /// Expected: Event does not appear on the day spread.
    @Test func testEventDoesNotAppearOnDaySpreadWhenDateDoesNotOverlap() {
        let service = Self.makeService()
        let calendar = Self.testCalendar
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let differentDay = calendar.date(from: .init(year: 2026, month: 1, day: 16))!
        let event = DataModel.Event(
            title: "Test Event",
            startDate: differentDay,
            endDate: differentDay
        )

        let result = service.eventAppearsOnSpread(event, spread: daySpread)

        #expect(result == false)
    }

    // MARK: - Event Visibility: Multiday Spread Tests

    /// Conditions: An event's date falls within the multiday spread range.
    /// Expected: Event appears on the multiday spread.
    @Test func testEventAppearsOnMultidaySpreadWhenDateRangeOverlaps() {
        let service = Self.makeService()
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let multidaySpread = Self.makeMultidaySpread(startDate: startDate, endDate: endDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )

        let result = service.eventAppearsOnSpread(event, spread: multidaySpread)

        #expect(result == true)
    }

    /// Conditions: An event's date falls outside the multiday spread range.
    /// Expected: Event does not appear on the multiday spread.
    @Test func testEventDoesNotAppearOnMultidaySpreadWhenDateRangeDoesNotOverlap() {
        let service = Self.makeService()
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 14))!
        let multidaySpread = Self.makeMultidaySpread(startDate: startDate, endDate: endDate)
        let event = DataModel.Event(
            title: "Test Event",
            startDate: Self.testDate,
            endDate: Self.testDate
        )

        let result = service.eventAppearsOnSpread(event, spread: multidaySpread)

        #expect(result == false)
    }

    /// Conditions: A multi-day event spans three days with day spreads for each day.
    /// Expected: Event appears on each day spread.
    @Test func testMultiDayEventAppearsOnMultipleDaySpreads() {
        let service = Self.makeService()
        let calendar = Self.testCalendar
        let day1 = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
        let day2 = calendar.date(from: .init(year: 2026, month: 1, day: 16))!
        let day3 = calendar.date(from: .init(year: 2026, month: 1, day: 17))!
        let daySpread1 = Self.makeSpread(period: .day, date: day1)
        let daySpread2 = Self.makeSpread(period: .day, date: day2)
        let daySpread3 = Self.makeSpread(period: .day, date: day3)
        let event = DataModel.Event(
            title: "Multi-day Event",
            timing: .multiDay,
            startDate: day1,
            endDate: day3
        )

        let appears1 = service.eventAppearsOnSpread(event, spread: daySpread1)
        let appears2 = service.eventAppearsOnSpread(event, spread: daySpread2)
        let appears3 = service.eventAppearsOnSpread(event, spread: daySpread3)

        #expect(appears1 == true)
        #expect(appears2 == true)
        #expect(appears3 == true)
    }

    // MARK: - Edge Case Tests

    /// Conditions: A month-period task is in a different month than the month spread.
    /// Expected: Service returns nil.
    @Test func testTaskWithDifferentMonthDoesNotMatchMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let task = Self.makeTask(date: Self.differentMonthDate, period: .month)

        let result = service.findBestSpread(for: task, in: [monthSpread])

        #expect(result == nil)
    }

    /// Conditions: A year-period task has two year spreads for different years available.
    /// Expected: Service returns the spread matching the task's year.
    @Test func testTaskMatchesCorrectYearSpread() {
        let service = Self.makeService()
        let yearSpread2026 = Self.makeSpread(period: .year, date: Self.testDate)
        let yearSpread2027 = Self.makeSpread(period: .year, date: Self.differentYearDate)
        let task = Self.makeTask(date: Self.testDate, period: .year)

        let result = service.findBestSpread(for: task, in: [yearSpread2026, yearSpread2027])

        #expect(result?.id == yearSpread2026.id)
    }
}
