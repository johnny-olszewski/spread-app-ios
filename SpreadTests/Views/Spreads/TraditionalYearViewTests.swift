import Foundation
import Testing
@testable import Spread

/// Tests for the year aggregation logic used by TraditionalYearView.
///
/// Validates that entry counts are correctly computed per month
/// and that the virtual spread data model provides accurate data
/// for the year grid display.
struct TraditionalYearViewTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static func makeService() -> TraditionalSpreadService {
        TraditionalSpreadService(calendar: testCalendar)
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        testCalendar.date(from: .init(year: year, month: month, day: day))!
    }

    private static func makeTask(
        title: String = "Task",
        date: Date,
        period: Period,
        status: DataModel.Task.Status = .open
    ) -> DataModel.Task {
        DataModel.Task(title: title, date: date, period: period, status: status)
    }

    private static func makeNote(
        title: String = "Note",
        date: Date,
        period: Period
    ) -> DataModel.Note {
        DataModel.Note(title: title, date: date, period: period)
    }

    // MARK: - Year Aggregation

    /// Year view should show entry counts per month across all entry types.
    /// Setup: 2 tasks in January, 1 note in February, no entries in March.
    /// Expected: Jan=2, Feb=1, Mar=0.
    @Test func testMonthEntryCountsAcrossEntryTypes() {
        let service = Self.makeService()
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan20 = Self.makeDate(year: 2026, month: 1, day: 20)
        let feb10 = Self.makeDate(year: 2026, month: 2, day: 10)
        let jan1 = Self.makeDate(year: 2026, month: 1)
        let feb1 = Self.makeDate(year: 2026, month: 2)
        let mar1 = Self.makeDate(year: 2026, month: 3)

        let tasks = [
            Self.makeTask(title: "Jan Task 1", date: jan15, period: .day),
            Self.makeTask(title: "Jan Task 2", date: jan20, period: .day),
        ]
        let notes = [
            Self.makeNote(title: "Feb Note", date: feb10, period: .day),
        ]

        let janModel = service.virtualSpreadDataModel(
            period: .month, date: jan1, tasks: tasks, notes: notes, events: []
        )
        let febModel = service.virtualSpreadDataModel(
            period: .month, date: feb1, tasks: tasks, notes: notes, events: []
        )
        let marModel = service.virtualSpreadDataModel(
            period: .month, date: mar1, tasks: tasks, notes: notes, events: []
        )

        #expect(janModel.tasks.count + janModel.notes.count == 2)
        #expect(febModel.tasks.count + febModel.notes.count == 1)
        #expect(marModel.tasks.count + marModel.notes.count == 0)
    }

    /// Cancelled tasks remain visible in month entry counts.
    /// Setup: 1 open task and 1 cancelled task in January.
    /// Expected: Jan count = 2.
    @Test func testCancelledTasksIncludedInCounts() {
        let service = Self.makeService()
        let jan15 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan1 = Self.makeDate(year: 2026, month: 1)

        let tasks = [
            Self.makeTask(title: "Open Task", date: jan15, period: .day, status: .open),
            Self.makeTask(title: "Cancelled Task", date: jan15, period: .day, status: .cancelled),
        ]

        let model = service.virtualSpreadDataModel(
            period: .month, date: jan1, tasks: tasks, notes: [], events: []
        )

        #expect(model.tasks.count == 2)
        #expect(model.tasks.map(\.title) == ["Open Task", "Cancelled Task"])
    }

    /// Month-period tasks should appear in their respective month's count.
    /// Setup: 1 month-period task for January.
    /// Expected: Shows in January month.
    @Test func testMonthPeriodTaskAppearsInMonthCount() {
        let service = Self.makeService()
        let jan1 = Self.makeDate(year: 2026, month: 1)

        let tasks = [
            Self.makeTask(title: "Monthly Task", date: jan1, period: .month),
        ]

        let model = service.virtualSpreadDataModel(
            period: .month, date: jan1, tasks: tasks, notes: [], events: []
        )

        #expect(model.tasks.count == 1)
    }

    /// All 12 months can be generated for a given year.
    /// Setup: Generate month dates for 2026.
    /// Expected: 12 dates, one for each month.
    @Test func testAllTwelveMonthsGenerated() {
        let calendar = Self.testCalendar
        let year = 2026

        let months: [Date] = (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }

        #expect(months.count == 12)

        for (index, monthDate) in months.enumerated() {
            let month = calendar.component(.month, from: monthDate)
            #expect(month == index + 1)
        }
    }

    /// Entries from different years should not appear in the year's month counts.
    /// Setup: Tasks in Jan 2026 and Jan 2027.
    /// Expected: Jan 2026 month only shows 2026 task.
    @Test func testEntriesFromOtherYearsExcluded() {
        let service = Self.makeService()
        let jan15_2026 = Self.makeDate(year: 2026, month: 1, day: 15)
        let jan15_2027 = Self.makeDate(year: 2027, month: 1, day: 15)
        let jan1_2026 = Self.makeDate(year: 2026, month: 1)

        let tasks = [
            Self.makeTask(title: "2026 Task", date: jan15_2026, period: .day),
            Self.makeTask(title: "2027 Task", date: jan15_2027, period: .day),
        ]

        let model = service.virtualSpreadDataModel(
            period: .month, date: jan1_2026, tasks: tasks, notes: [], events: []
        )

        #expect(model.tasks.count == 1)
        #expect(model.tasks.first?.title == "2026 Task")
    }

    /// Year-period entries should appear on the year's aggregate but not on individual months.
    /// Setup: 1 year-period task for 2026.
    /// Expected: Does not appear on January month (coarser period excluded from finer).
    @Test func testYearPeriodTaskDoesNotAppearOnMonth() {
        let service = Self.makeService()
        let year2026 = Self.makeDate(year: 2026, month: 1)

        let tasks = [
            Self.makeTask(title: "Year Task", date: year2026, period: .year),
        ]

        let model = service.virtualSpreadDataModel(
            period: .month, date: year2026, tasks: tasks, notes: [], events: []
        )

        #expect(model.tasks.count == 0)
    }

    /// Year view should show year-period tasks when viewing the year spread data model.
    /// Setup: 1 year-period task for 2026.
    /// Expected: Year model includes the task.
    @Test func testYearPeriodTaskAppearsOnYearSpread() {
        let service = Self.makeService()
        let year2026 = Self.makeDate(year: 2026, month: 1)

        let tasks = [
            Self.makeTask(title: "Year Task", date: year2026, period: .year),
        ]

        let model = service.virtualSpreadDataModel(
            period: .year, date: year2026, tasks: tasks, notes: [], events: []
        )

        #expect(model.tasks.count == 1)
    }
}
