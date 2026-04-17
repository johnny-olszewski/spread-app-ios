import Foundation
import Testing
@testable import Spread

/// Tests for day entry count logic used by the traditional month view.
/// Calendar grid layout is handled by `MonthCalendarModelBuilder` in `johnnyo-foundation`;
/// those tests live in the package's own test target.
struct TraditionalMonthViewTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        testCalendar.date(from: .init(year: year, month: month, day: day))!
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
