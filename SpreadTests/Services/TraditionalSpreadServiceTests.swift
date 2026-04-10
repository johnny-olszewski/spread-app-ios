import Foundation
import Testing
@testable import Spread

struct TraditionalSpreadServiceTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    /// January 15, 2026
    private static var jan15: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    /// January 1, 2026
    private static var jan1: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 1))!
    }

    /// February 10, 2026
    private static var feb10: Date {
        testCalendar.date(from: .init(year: 2026, month: 2, day: 10))!
    }

    /// February 1, 2026
    private static var feb1: Date {
        testCalendar.date(from: .init(year: 2026, month: 2, day: 1))!
    }

    /// March 5, 2026
    private static var mar5: Date {
        testCalendar.date(from: .init(year: 2026, month: 3, day: 5))!
    }

    /// January 1, 2026 (year normalized)
    private static var year2026: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 1))!
    }

    /// January 1, 2027 (year normalized)
    private static var year2027: Date {
        testCalendar.date(from: .init(year: 2027, month: 1, day: 1))!
    }

    private static func makeService() -> TraditionalSpreadService {
        TraditionalSpreadService(calendar: testCalendar)
    }

    private static func makeTask(
        title: String = "Test Task",
        date: Date,
        period: Period,
        status: DataModel.Task.Status = .open
    ) -> DataModel.Task {
        DataModel.Task(title: title, date: date, period: period, status: status)
    }

    private static func makeNote(
        title: String = "Test Note",
        date: Date,
        period: Period
    ) -> DataModel.Note {
        DataModel.Note(title: title, date: date, period: period)
    }

    private static func makeEvent(
        title: String = "Test Event",
        startDate: Date,
        endDate: Date
    ) -> DataModel.Event {
        DataModel.Event(title: title, startDate: startDate, endDate: endDate)
    }

    private static func makeSpread(period: Period, date: Date) -> DataModel.Spread {
        DataModel.Spread(period: period, date: date, calendar: testCalendar)
    }

    // MARK: - Entry Matching: Day Spread

    /// A day-period task on Jan 15 should appear on the Jan 15 day spread.
    @Test func testDayTaskAppearsOnMatchingDaySpread() {
        let service = Self.makeService()
        let normalizedDate = Period.day.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan15, period: .day),
            period: .day,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    /// A day-period task on Jan 15 should NOT appear on the Feb 10 day spread.
    @Test func testDayTaskDoesNotAppearOnDifferentDaySpread() {
        let service = Self.makeService()
        let normalizedDate = Period.day.normalizeDate(Self.feb10, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan15, period: .day),
            period: .day,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    // MARK: - Entry Matching: Month Spread

    /// A day-period task on Jan 15 should appear on the January 2026 month spread.
    @Test func testDayTaskAppearsOnContainingMonthSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.month.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan15, period: .day),
            period: .month,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    /// A month-period task for January should appear on the January month spread.
    @Test func testMonthTaskAppearsOnMatchingMonthSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.month.normalizeDate(Self.jan1, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan1, period: .month),
            period: .month,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    /// A month-period task for January should NOT appear on the February month spread.
    @Test func testMonthTaskDoesNotAppearOnDifferentMonthSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.month.normalizeDate(Self.feb1, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan1, period: .month),
            period: .month,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    // MARK: - Entry Matching: Year Spread

    /// A day-period task on Jan 15 2026 should appear on the 2026 year spread.
    @Test func testDayTaskAppearsOnContainingYearSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.year.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan15, period: .day),
            period: .year,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    /// A month-period task for January 2026 should appear on the 2026 year spread.
    @Test func testMonthTaskAppearsOnContainingYearSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.year.normalizeDate(Self.jan1, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan1, period: .month),
            period: .year,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    /// A year-period task for 2026 should appear on the 2026 year spread.
    @Test func testYearTaskAppearsOnMatchingYearSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.year.normalizeDate(Self.year2026, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.year2026, period: .year),
            period: .year,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    // MARK: - Entry Matching: Coarser-Than-Spread

    /// A year-period task should NOT appear on a month spread.
    @Test func testYearTaskDoesNotAppearOnMonthSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.month.normalizeDate(Self.jan1, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.year2026, period: .year),
            period: .month,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    /// A month-period task should NOT appear on a day spread.
    @Test func testMonthTaskDoesNotAppearOnDaySpread() {
        let service = Self.makeService()
        let normalizedDate = Period.day.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan1, period: .month),
            period: .day,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    /// A year-period task should NOT appear on a day spread.
    @Test func testYearTaskDoesNotAppearOnDaySpread() {
        let service = Self.makeService()
        let normalizedDate = Period.day.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.year2026, period: .year),
            period: .day,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    // MARK: - Entry Matching: Multiday Exclusion

    /// Multiday period entries should not appear on any virtual spread.
    @Test func testMultidayEntryDoesNotAppearOnVirtualSpreads() {
        let service = Self.makeService()
        let normalizedDate = Period.month.normalizeDate(Self.jan1, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan15, period: .multiday),
            period: .month,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    /// Multiday spread period should not match any entries.
    @Test func testMultidaySpreadPeriodDoesNotMatchEntries() {
        let service = Self.makeService()
        let normalizedDate = Period.multiday.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.taskBelongsOnSpread(
            Self.makeTask(date: Self.jan15, period: .day),
            period: .multiday,
            normalizedDate: normalizedDate
        )

        #expect(result == false)
    }

    // MARK: - Entry Matching: Notes

    /// A note with day-period on Jan 15 should appear on the January month spread.
    @Test func testDayNoteAppearsOnContainingMonthSpread() {
        let service = Self.makeService()
        let normalizedDate = Period.month.normalizeDate(Self.jan15, calendar: Self.testCalendar)

        let result = service.noteBelongsOnSpread(
            Self.makeNote(date: Self.jan15, period: .day),
            period: .month,
            normalizedDate: normalizedDate
        )

        #expect(result == true)
    }

    // MARK: - Virtual Spread Data Model

    /// Virtual spread data model includes entries with matching preferred dates, including cancelled tasks.
    @Test func testVirtualSpreadDataModelFiltersCorrectly() {
        let service = Self.makeService()

        let janTask = Self.makeTask(title: "Jan Task", date: Self.jan15, period: .day)
        let febTask = Self.makeTask(title: "Feb Task", date: Self.feb10, period: .day)
        let janNote = Self.makeNote(title: "Jan Note", date: Self.jan15, period: .day)
        let cancelledTask = Self.makeTask(title: "Cancelled", date: Self.jan15, period: .day, status: .cancelled)

        let result = service.virtualSpreadDataModel(
            period: .month,
            date: Self.jan1,
            tasks: [janTask, febTask, cancelledTask],
            notes: [janNote],
            events: []
        )

        #expect(result.tasks.count == 2)
        #expect(result.tasks.map(\.title) == ["Jan Task", "Cancelled"])
        #expect(result.notes.count == 1)
        #expect(result.notes.first?.title == "Jan Note")
    }

    /// Cancelled tasks remain visible in virtual spread data models.
    @Test func testVirtualSpreadIncludesCancelledTasks() {
        let service = Self.makeService()

        let openTask = Self.makeTask(title: "Open", date: Self.jan15, period: .day)
        let cancelledTask = Self.makeTask(title: "Cancelled", date: Self.jan15, period: .day, status: .cancelled)

        let result = service.virtualSpreadDataModel(
            period: .day,
            date: Self.jan15,
            tasks: [openTask, cancelledTask],
            notes: [],
            events: []
        )

        #expect(result.tasks.count == 2)
        #expect(result.tasks.map(\.title) == ["Open", "Cancelled"])
    }

    // MARK: - Years With Entries

    /// yearsWithEntries returns sorted distinct years from all entry types.
    @Test func testYearsWithEntriesReturnsDistinctSortedYears() {
        let service = Self.makeService()

        let task2026 = Self.makeTask(date: Self.jan15, period: .day)
        let task2027 = Self.makeTask(
            date: Self.testCalendar.date(from: .init(year: 2027, month: 3, day: 1))!,
            period: .day
        )
        let note2026 = Self.makeNote(date: Self.feb10, period: .month)

        let years = service.yearsWithEntries(
            tasks: [task2026, task2027],
            notes: [note2026],
            events: []
        )

        #expect(years.count == 2)
        let yearComponents = years.map { Self.testCalendar.component(.year, from: $0) }
        #expect(yearComponents == [2026, 2027])
    }

    /// Cancelled tasks still contribute yearsWithEntries because they remain visible.
    @Test func testYearsWithEntriesIncludesCancelledTasks() {
        let service = Self.makeService()

        let cancelledTask = Self.makeTask(date: Self.jan15, period: .day, status: .cancelled)
        let activeTask = Self.makeTask(
            date: Self.testCalendar.date(from: .init(year: 2027, month: 1, day: 1))!,
            period: .day
        )

        let years = service.yearsWithEntries(tasks: [cancelledTask, activeTask], notes: [], events: [])

        #expect(years.count == 2)
        let yearComponents = years.map { Self.testCalendar.component(.year, from: $0) }
        #expect(yearComponents == [2026, 2027])
    }

    // MARK: - Months With Entries

    /// monthsWithEntries returns months within a specific year.
    @Test func testMonthsWithEntriesInYear() {
        let service = Self.makeService()

        let janTask = Self.makeTask(date: Self.jan15, period: .day)
        let febTask = Self.makeTask(date: Self.feb10, period: .day)
        let marNote = Self.makeNote(date: Self.mar5, period: .day)

        let months = service.monthsWithEntries(
            inYear: Self.year2026,
            tasks: [janTask, febTask],
            notes: [marNote],
            events: []
        )

        #expect(months.count == 3)
        let monthNumbers = months.map { Self.testCalendar.component(.month, from: $0) }
        #expect(monthNumbers == [1, 2, 3])
    }

    /// monthsWithEntries excludes entries from other years.
    @Test func testMonthsWithEntriesExcludesOtherYears() {
        let service = Self.makeService()

        let task2026 = Self.makeTask(date: Self.jan15, period: .day)
        let task2027 = Self.makeTask(
            date: Self.testCalendar.date(from: .init(year: 2027, month: 6, day: 1))!,
            period: .day
        )

        let months = service.monthsWithEntries(
            inYear: Self.year2026,
            tasks: [task2026, task2027],
            notes: [],
            events: []
        )

        #expect(months.count == 1)
        #expect(Self.testCalendar.component(.month, from: months[0]) == 1)
    }

    // MARK: - Days With Entries

    /// daysWithEntries returns day dates for day-period entries in a month.
    @Test func testDaysWithEntriesInMonth() {
        let service = Self.makeService()

        let jan15Task = Self.makeTask(date: Self.jan15, period: .day)
        let jan20 = Self.testCalendar.date(from: .init(year: 2026, month: 1, day: 20))!
        let jan20Task = Self.makeTask(date: jan20, period: .day)

        let days = service.daysWithEntries(
            inMonth: Self.jan1,
            tasks: [jan15Task, jan20Task],
            notes: [],
            events: []
        )

        #expect(days.count == 2)
        let dayNumbers = days.map { Self.testCalendar.component(.day, from: $0) }
        #expect(dayNumbers == [15, 20])
    }

    /// daysWithEntries excludes month-period and year-period entries.
    @Test func testDaysWithEntriesExcludesCoarserPeriods() {
        let service = Self.makeService()

        let dayTask = Self.makeTask(date: Self.jan15, period: .day)
        let monthTask = Self.makeTask(date: Self.jan1, period: .month)
        let yearTask = Self.makeTask(date: Self.year2026, period: .year)

        let days = service.daysWithEntries(
            inMonth: Self.jan1,
            tasks: [dayTask, monthTask, yearTask],
            notes: [],
            events: []
        )

        #expect(days.count == 1)
        #expect(Self.testCalendar.component(.day, from: days[0]) == 15)
    }

    // MARK: - Conventional Spread Fallback

    /// findConventionalSpread returns exact match when a conventional spread exists.
    @Test func testFindConventionalSpreadExactMatch() {
        let service = Self.makeService()
        let daySpread = Self.makeSpread(period: .day, date: Self.jan15)

        let result = service.findConventionalSpread(
            forPreferredDate: Self.jan15,
            preferredPeriod: .day,
            in: [daySpread]
        )

        #expect(result?.id == daySpread.id)
    }

    /// findConventionalSpread falls back to month when no day spread exists.
    @Test func testFindConventionalSpreadFallsBackToMonth() {
        let service = Self.makeService()
        let monthSpread = Self.makeSpread(period: .month, date: Self.jan1)

        let result = service.findConventionalSpread(
            forPreferredDate: Self.jan15,
            preferredPeriod: .day,
            in: [monthSpread]
        )

        #expect(result?.id == monthSpread.id)
    }

    /// findConventionalSpread falls back to year when no day or month spread exists.
    @Test func testFindConventionalSpreadFallsBackToYear() {
        let service = Self.makeService()
        let yearSpread = Self.makeSpread(period: .year, date: Self.year2026)

        let result = service.findConventionalSpread(
            forPreferredDate: Self.jan15,
            preferredPeriod: .day,
            in: [yearSpread]
        )

        #expect(result?.id == yearSpread.id)
    }

    /// findConventionalSpread returns nil (Inbox) when no conventional spread matches.
    @Test func testFindConventionalSpreadReturnsNilForInbox() {
        let service = Self.makeService()

        let result = service.findConventionalSpread(
            forPreferredDate: Self.jan15,
            preferredPeriod: .day,
            in: []
        )

        #expect(result == nil)
    }

    /// findConventionalSpread returns nil when only unrelated spreads exist.
    @Test func testFindConventionalSpreadIgnoresUnrelatedSpreads() {
        let service = Self.makeService()
        let febMonthSpread = Self.makeSpread(period: .month, date: Self.feb1)

        let result = service.findConventionalSpread(
            forPreferredDate: Self.jan15,
            preferredPeriod: .day,
            in: [febMonthSpread]
        )

        #expect(result == nil)
    }
}
