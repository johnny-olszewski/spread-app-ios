import Foundation
import Testing
@testable import Spread

/// Tests for calendar grid generation and day selection mapping
/// used by TraditionalMonthView.
struct TraditionalMonthViewTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    private static var mondayFirstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        testCalendar.date(from: .init(year: year, month: month, day: day))!
    }

    // MARK: - Calendar Grid: Cell Count

    /// Grid cells for a 28-day month (Feb 2026, starts on Sunday with Sunday-first calendar).
    /// Feb 1, 2026 is a Sunday. 28 days, no leading empties, 0 trailing = 28 cells.
    @Test func testFebruary2026SundayFirstHas28Cells() {
        let feb2026 = Self.makeDate(year: 2026, month: 2)
        let cells = CalendarGridHelper.cells(for: feb2026, calendar: Self.testCalendar)

        // Feb 2026 starts on Sunday (weekday 1), so 0 leading empties
        // 28 days = 4 rows exactly = 28 cells
        #expect(cells.count == 28)
        #expect(cells.count % 7 == 0)
    }

    /// Grid cells for March 2026 (31 days, starts on Sunday).
    /// 31 days + 0 leading = 31, padded to 35.
    @Test func testMarch2026SundayFirstHas35Cells() {
        let mar2026 = Self.makeDate(year: 2026, month: 3)
        let cells = CalendarGridHelper.cells(for: mar2026, calendar: Self.testCalendar)

        // Mar 1, 2026 is a Sunday, so 0 leading empties
        // 31 days, padded to 35 (5 rows)
        #expect(cells.count == 35)
        #expect(cells.count % 7 == 0)
    }

    // MARK: - Calendar Grid: Leading Empty Cells

    /// When a month starts mid-week, leading cells should be nil.
    /// April 2026 starts on Wednesday (weekday 4 in Sunday-first).
    @Test func testApril2026HasLeadingEmptyCells() {
        let apr2026 = Self.makeDate(year: 2026, month: 4)
        let cells = CalendarGridHelper.cells(for: apr2026, calendar: Self.testCalendar)

        // April 1, 2026 is Wednesday (weekday 4), Sunday-first calendar
        // Leading empties: 4 - 1 = 3
        #expect(cells[0] == nil)
        #expect(cells[1] == nil)
        #expect(cells[2] == nil)
        #expect(cells[3] != nil)

        // First actual day should be April 1
        let firstDay = cells[3]!
        #expect(Self.testCalendar.component(.day, from: firstDay) == 1)
    }

    // MARK: - Calendar Grid: All Days Present

    /// All days of the month should be present in the grid.
    /// Setup: January 2026 has 31 days.
    /// Expected: 31 non-nil cells.
    @Test func testAllDaysOfMonthPresent() {
        let jan2026 = Self.makeDate(year: 2026, month: 1)
        let cells = CalendarGridHelper.cells(for: jan2026, calendar: Self.testCalendar)

        let nonNilCells = cells.compactMap { $0 }
        #expect(nonNilCells.count == 31)

        // Verify day numbers are 1-31
        let dayNumbers = nonNilCells.map { Self.testCalendar.component(.day, from: $0) }
        #expect(dayNumbers == Array(1...31))
    }

    // MARK: - Calendar Grid: Monday-First

    /// Monday-first calendar should shift the grid layout.
    /// Feb 2026 starts on Sunday, which is the last column in Monday-first.
    @Test func testMondayFirstCalendarShiftsGrid() {
        let feb2026 = Self.makeDate(year: 2026, month: 2)
        let cells = CalendarGridHelper.cells(for: feb2026, calendar: Self.mondayFirstCalendar)

        // Feb 1, 2026 is Sunday (weekday 1)
        // Monday-first: Sun is column 7, so leading empties = 1 - 2 = -1 + 7 = 6
        let leadingNils = cells.prefix(while: { $0 == nil }).count
        #expect(leadingNils == 6)

        // First actual day
        let firstDay = cells[6]!
        #expect(Self.testCalendar.component(.day, from: firstDay) == 1)
    }

    // MARK: - Calendar Grid: Trailing Cells

    /// Grid should always have a multiple of 7 cells (complete rows).
    @Test func testGridAlwaysHasCompleteRows() {
        // Test multiple months
        for month in 1...12 {
            let monthDate = Self.makeDate(year: 2026, month: month)
            let cells = CalendarGridHelper.cells(for: monthDate, calendar: Self.testCalendar)
            #expect(
                cells.count % 7 == 0,
                "Month \(month) has \(cells.count) cells, not a multiple of 7"
            )
        }
    }

    // MARK: - Day Entry Count Logic

    /// Day entry counts should match the virtual spread data model.
    /// Setup: 2 day-period tasks on Jan 15.
    /// Expected: Day entry count for Jan 15 is 2.
    @Test func testDayEntryCountMatchesVirtualSpread() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Task 1", date: jan15, period: .day),
            DataModel.Task(title: "Task 2", date: jan15, period: .day),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.count == 2)
    }

    /// Days without entries should have zero count.
    /// Setup: Tasks on Jan 15, checking Jan 16.
    /// Expected: Jan 16 has 0 entries.
    @Test func testDayWithNoEntriesHasZeroCount() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan16 = Self.makeDate(year: 2026, month: 1, day: 16)

        let tasks = [
            DataModel.Task(title: "Task 1", date: jan15, period: .day),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan16, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.count == 0)
    }

    /// Month-period entries should not appear in day-level counts.
    /// Setup: Month-period task in January, checking Jan 15 day.
    /// Expected: Day entry count is 0.
    @Test func testMonthPeriodEntriesExcludedFromDayCounts() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan1 = Self.makeDate(year: 2026, month: 1)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Monthly Task", date: jan1, period: .month),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.count == 0)
    }
}
