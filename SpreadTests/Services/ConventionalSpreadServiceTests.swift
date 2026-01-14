import struct Foundation.Calendar
import struct Foundation.Date
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

    @Test func testTaskWithDayPeriodMatchesDaySpread() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [daySpread])

        #expect(result?.id == daySpread.id)
    }

    @Test func testTaskWithMonthPeriodMatchesMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .month)

        let result = service.findBestSpread(for: task, in: [monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    @Test func testTaskWithYearPeriodMatchesYearSpread() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .year)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result?.id == yearSpread.id)
    }

    // MARK: - Task Assignment: Fallback Tests (Finest to Coarsest)

    @Test func testTaskWithDayPeriodFallsBackToMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    @Test func testTaskWithDayPeriodFallsBackToYearSpread() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result?.id == yearSpread.id)
    }

    @Test func testTaskWithMonthPeriodFallsBackToYearSpread() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .month)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result?.id == yearSpread.id)
    }

    @Test func testTaskPrefersFinestMatchingSpread() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [yearSpread, monthSpread, daySpread])

        #expect(result?.id == daySpread.id)
    }

    @Test func testTaskWithMonthPeriodPrefersMonthOverYear() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let yearSpread = Self.makeSpread(period: .year, date: Self.testDate)
        let task = Self.makeTask(date: Self.testDate, period: .month)

        let result = service.findBestSpread(for: task, in: [yearSpread, monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    // MARK: - Task Assignment: No Match Tests

    @Test func testTaskReturnsNilWhenNoSpreadExists() {
        let service = Self.makeService()
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [])

        #expect(result == nil)
    }

    @Test func testTaskReturnsNilWhenNoMatchingDateSpreadExists() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.differentYearDate)
        let task = Self.makeTask(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: task, in: [yearSpread])

        #expect(result == nil)
    }

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

    @Test func testNoteWithDayPeriodMatchesDaySpread() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.testDate)
        let note = Self.makeNote(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: note, in: [daySpread])

        #expect(result?.id == daySpread.id)
    }

    @Test func testNoteWithDayPeriodFallsBackToMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let note = Self.makeNote(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: note, in: [monthSpread])

        #expect(result?.id == monthSpread.id)
    }

    @Test func testNoteReturnsNilWhenNoSpreadExists() {
        let service = Self.makeService()
        let note = Self.makeNote(date: Self.testDate, period: .day)

        let result = service.findBestSpread(for: note, in: [])

        #expect(result == nil)
    }

    // MARK: - Event Visibility: Year Spread Tests

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

    @Test func testTaskWithDifferentMonthDoesNotMatchMonthSpread() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.testDate)
        let task = Self.makeTask(date: Self.differentMonthDate, period: .month)

        let result = service.findBestSpread(for: task, in: [monthSpread])

        #expect(result == nil)
    }

    @Test func testTaskMatchesCorrectYearSpread() {
        let service = Self.makeService()
        let yearSpread2026 = Self.makeSpread(period: .year, date: Self.testDate)
        let yearSpread2027 = Self.makeSpread(period: .year, date: Self.differentYearDate)
        let task = Self.makeTask(date: Self.testDate, period: .year)

        let result = service.findBestSpread(for: task, in: [yearSpread2026, yearSpread2027])

        #expect(result?.id == yearSpread2026.id)
    }
}
