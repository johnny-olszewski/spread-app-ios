import Foundation
import Testing
@testable import Spread

/// Tests for YearSpreadContentView static helpers.
///
/// YearSpreadContentSupport was removed when traditional mode was deleted.
/// Entry routing logic is now inline in YearSpreadContentView; the only public
/// surface is `YearSpreadContentView.entriesForMonth(_:from:calendar:)`.
@MainActor
struct YearSpreadContentSupportTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - entriesForMonth

    /// When a SpreadDataModel has year-period, month-period, and day-period entries,
    /// entriesForMonth for January should include only January month- and day-period entries —
    /// year-period entries and entries from other months are excluded.
    @Test func entriesForMonthIncludesMonthAndDayPeriodEntriesForThatMonth() {
        let yearDate = Self.makeDate(year: 2026, month: 1)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: Self.calendar)

        var spreadDataModel = SpreadDataModel(spread: yearSpread)
        let yearTask = DataModel.Task(title: "Year Task", date: yearDate, period: .year)
        let januaryMonthTask = DataModel.Task(title: "January Month Task", date: yearDate, period: .month)
        let januaryDayNote = DataModel.Note(
            title: "January Day Note",
            date: Self.makeDate(year: 2026, month: 1, day: 18),
            period: .day
        )
        let marchDayTask = DataModel.Task(
            title: "March Day Task",
            date: Self.makeDate(year: 2026, month: 3, day: 7),
            period: .day
        )

        spreadDataModel.tasks = [yearTask, januaryMonthTask, marchDayTask]
        spreadDataModel.notes = [januaryDayNote]

        let januaryEntries = YearSpreadContentView.entriesForMonth(
            Self.makeDate(year: 2026, month: 1),
            from: spreadDataModel,
            calendar: Self.calendar
        )
        let marchEntries = YearSpreadContentView.entriesForMonth(
            Self.makeDate(year: 2026, month: 3),
            from: spreadDataModel,
            calendar: Self.calendar
        )

        // Year-period tasks are excluded; January gets its month + day entries
        #expect(januaryEntries.map(\.title) == ["January Month Task", "January Day Note"])
        // March gets only its day-period entry
        #expect(marchEntries.map(\.title) == ["March Day Task"])
    }

    /// When a task was migrated away from year scope but a current year assignment remains,
    /// entriesForMonth should still include day-period entries in their correct month card.
    @Test func migratedHistoryTasksAreExcludedFromYearEntriesButDayEntriesAppearInMonthCards() async throws {
        let yearDate = Self.makeDate(year: 2026, month: 1)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: yearDate, calendar: Self.calendar)

        let currentYearTask = DataModel.Task(
            title: "Current Year Task",
            date: Self.makeDate(year: 2026, month: 1, day: 12),
            period: .day,
            currentAssignments: [Assignment(period: .year, date: yearDate, status: .open)]
        )
        let migratedHistoryTask = DataModel.Task(
            title: "Migrated Away",
            date: Self.makeDate(year: 2026, month: 1, day: 13),
            period: .day,
            currentAssignments: [
                Assignment(period: .month, date: yearDate, status: .open)
            ],
            migrationHistory: [
                Assignment(period: .year, date: yearDate, status: .migrated)
            ]
        )

        let manager = try await JournalManager(
            calendar: Self.calendar,
            today: Self.makeDate(year: 2026, month: 1, day: 15),
            taskRepository: TestTaskRepository(tasks: [currentYearTask, migratedHistoryTask]),
            spreadRepository: TestSpreadRepository(spreads: [yearSpread, monthSpread])
        )

        let dataModel = try #require(manager.dataModel[.year]?[Period.year.normalizeDate(yearDate, calendar: Self.calendar)])
        let januaryEntries = YearSpreadContentView.entriesForMonth(
            Self.makeDate(year: 2026, month: 1),
            from: dataModel,
            calendar: Self.calendar
        )

        // Only the currently-active (non-migrated) day task should appear in January's card
        #expect(januaryEntries.map(\.title) == ["Current Year Task"])
    }
}
