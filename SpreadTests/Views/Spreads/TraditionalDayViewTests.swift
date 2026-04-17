import Foundation
import Testing
@testable import Spread

/// Tests for day entry filtering logic used by TraditionalDayView.
struct TraditionalDayViewTests {

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

    // MARK: - Day Entry Filtering

    /// Day view should show day-period tasks whose preferred date matches.
    /// Setup: Two tasks on Jan 15 with period .day.
    /// Expected: Both tasks appear in the day data model.
    @Test func testDayViewShowsMatchingDayTasks() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Task A", date: jan15, period: .day),
            DataModel.Task(title: "Task B", date: jan15, period: .day),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.count == 2)
        #expect(dataModel.spread.period == .day)
    }

    /// Day view should show day-period notes whose preferred date matches.
    /// Setup: One note on Jan 15 with period .day.
    /// Expected: Note appears in the day data model.
    @Test func testDayViewShowsMatchingDayNotes() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let notes = [
            DataModel.Note(title: "Note A", date: jan15, period: .day),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: [], notes: notes, events: []
        )

        #expect(dataModel.notes.count == 1)
    }

    /// Day view should not show tasks from a different day.
    /// Setup: Task on Jan 15, viewing Jan 16.
    /// Expected: No tasks in the day data model.
    @Test func testDayViewExcludesTasksFromOtherDays() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan16 = Self.makeDate(year: 2026, month: 1, day: 16)

        let tasks = [
            DataModel.Task(title: "Task A", date: jan15, period: .day),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan16, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.isEmpty)
    }

    /// Day view should not show month-period tasks.
    /// Setup: Task with period .month in January, viewing Jan 15.
    /// Expected: No tasks (month-period tasks don't appear on day spreads).
    @Test func testDayViewExcludesMonthPeriodTasks() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan1 = Self.makeDate(year: 2026, month: 1)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Monthly Task", date: jan1, period: .month),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.isEmpty)
    }

    /// Day view should not show year-period tasks.
    /// Setup: Task with period .year in 2026, viewing Jan 15.
    /// Expected: No tasks (year-period tasks don't appear on day spreads).
    @Test func testDayViewExcludesYearPeriodTasks() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan1 = Self.makeDate(year: 2026, month: 1)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Yearly Task", date: jan1, period: .year),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.isEmpty)
    }

    /// Day view should exclude cancelled tasks.
    /// Setup: One open and one cancelled task on the same day.
    /// Expected: Both tasks appear, with cancelled styled later in the row layer.
    @Test func testDayViewIncludesCancelledTasks() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Open Task", date: jan15, period: .day, status: .open),
            DataModel.Task(title: "Cancelled Task", date: jan15, period: .day, status: .cancelled),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.count == 2)
        #expect(dataModel.tasks.map(\.title) == ["Open Task", "Cancelled Task"])
    }

    /// Day view should show completed tasks (they appear but greyed out).
    /// Setup: One completed task on Jan 15.
    /// Expected: Task appears in the data model.
    @Test func testDayViewShowsCompletedTasks() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Done Task", date: jan15, period: .day, status: .complete),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: [], events: []
        )

        #expect(dataModel.tasks.count == 1)
    }

    /// Day view should show mixed entry types for the same day.
    /// Setup: 2 tasks and 1 note on Jan 15.
    /// Expected: All 3 entries appear in the data model.
    @Test func testDayViewShowsMixedEntryTypes() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let tasks = [
            DataModel.Task(title: "Task 1", date: jan15, period: .day),
            DataModel.Task(title: "Task 2", date: jan15, period: .day),
        ]
        let notes = [
            DataModel.Note(title: "Note 1", date: jan15, period: .day),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: tasks, notes: notes, events: []
        )

        #expect(dataModel.tasks.count == 2)
        #expect(dataModel.notes.count == 1)
    }

    /// Day view should show events that span this day.
    /// Setup: Event from Jan 14-16, viewing Jan 15.
    /// Expected: Event appears in the data model.
    @Test func testDayViewShowsSpanningEvents() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan14 = Self.makeDate(year: 2026, month: 1, day: 14)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan16 = Self.makeDate(year: 2026, month: 1, day: 16)

        let events = [
            DataModel.Event(title: "Multi-day Event", startDate: jan14, endDate: jan16),
        ]

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: [], notes: [], events: events
        )

        #expect(dataModel.events.count == 1)
    }

    /// Day view virtual spread should have the correct date and period.
    /// Setup: Virtual spread for Jan 15.
    /// Expected: Spread has period .day and date normalized to Jan 15.
    @Test func testDayViewVirtualSpreadMetadata() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)

        let dataModel = service.virtualSpreadDataModel(
            period: .day, date: jan15, tasks: [], notes: [], events: []
        )

        #expect(dataModel.spread.period == .day)
        let spreadDay = Self.testCalendar.component(.day, from: dataModel.spread.date)
        let spreadMonth = Self.testCalendar.component(.month, from: dataModel.spread.date)
        #expect(spreadDay == 15)
        #expect(spreadMonth == 1)
    }
}
