import Foundation
import Testing
@testable import Spread

/// Tests for MigrationDestinationFormatter destination label formatting.
@Suite("MigrationDestinationFormatter Tests")
struct MigrationDestinationFormatterTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var formatter: MigrationDestinationFormatter {
        MigrationDestinationFormatter(calendar: Self.testCalendar)
    }

    // MARK: - Task Destination Tests

    /// Condition: Task migrated from year spread to month spread.
    /// Expected: Destination shows month abbreviation and year.
    @Test("Task migrated from year to month shows month label")
    func testTaskYearToMonth() {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let monthDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let spread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)

        let task = DataModel.Task(title: "Test", date: monthDate, period: .month, status: .migrated)
        task.assignments = [
            TaskAssignment(period: .year, date: yearDate, status: .migrated),
            TaskAssignment(period: .month, date: monthDate, status: .open)
        ]

        let result = formatter.destination(for: task, from: spread)
        #expect(result == "Feb 26")
    }

    /// Condition: Task migrated from month spread to day spread.
    /// Expected: Destination shows day date.
    @Test("Task migrated from month to day shows day label")
    func testTaskMonthToDay() {
        let calendar = Self.testCalendar
        let monthDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let spread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)

        let task = DataModel.Task(title: "Test", date: dayDate, period: .day, status: .migrated)
        task.assignments = [
            TaskAssignment(period: .month, date: monthDate, status: .migrated),
            TaskAssignment(period: .day, date: dayDate, status: .open)
        ]

        let result = formatter.destination(for: task, from: spread)
        #expect(result == "3/15/26")
    }

    /// Condition: Task migrated from year spread to day spread (skipping month).
    /// Expected: Destination shows the most specific (day) label.
    @Test("Task migrated from year to day shows most specific destination")
    func testTaskYearToDay() {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let spread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)

        let task = DataModel.Task(title: "Test", date: dayDate, period: .day, status: .migrated)
        task.assignments = [
            TaskAssignment(period: .year, date: yearDate, status: .migrated),
            TaskAssignment(period: .day, date: dayDate, status: .open)
        ]

        let result = formatter.destination(for: task, from: spread)
        #expect(result == "5/10/26")
    }

    /// Condition: Task has no assignment with a smaller period than the source spread.
    /// Expected: Returns nil (no destination found).
    @Test("Task with no smaller period assignment returns nil")
    func testTaskNoDestination() {
        let calendar = Self.testCalendar
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)

        let task = DataModel.Task(title: "Test", date: dayDate, period: .day, status: .migrated)
        task.assignments = [
            TaskAssignment(period: .day, date: dayDate, status: .migrated)
        ]

        let result = formatter.destination(for: task, from: spread)
        #expect(result == nil)
    }

    // MARK: - Note Destination Tests

    /// Condition: Note migrated from month spread to day spread.
    /// Expected: Destination shows day date.
    @Test("Note migrated from month to day shows day label")
    func testNoteMonthToDay() {
        let calendar = Self.testCalendar
        let monthDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 20))!
        let spread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)

        let note = DataModel.Note(title: "Test", date: dayDate, period: .day, status: .migrated)
        note.assignments = [
            NoteAssignment(period: .month, date: monthDate, status: .migrated),
            NoteAssignment(period: .day, date: dayDate, status: .active)
        ]

        let result = formatter.destination(for: note, from: spread)
        #expect(result == "4/20/26")
    }

    // MARK: - Multiday Destination Tests

    /// Condition: Task migrated to a multiday spread.
    /// Expected: Destination shows date with "+" suffix.
    @Test("Destination for multiday shows date with plus suffix")
    func testMultidayDestination() {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let multidayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let spread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)

        let task = DataModel.Task(title: "Test", date: multidayDate, period: .multiday, status: .migrated)
        task.assignments = [
            TaskAssignment(period: .year, date: yearDate, status: .migrated),
            TaskAssignment(period: .multiday, date: multidayDate, status: .open)
        ]

        let result = formatter.destination(for: task, from: spread)
        #expect(result == "1/5+")
    }

    // MARK: - Year Destination Tests

    /// Condition: Task has only a year-level destination from a higher context.
    /// Expected: Destination shows the year.
    @Test("Year destination shows year number")
    func testYearDestination() {
        let calendar = Self.testCalendar
        // Hypothetical: migrating from a broad context to a year spread
        // In practice this is rare, but the formatter should handle it
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let result = MigrationDestinationFormatter(calendar: calendar)
        let formatted = result.destination(
            for: DataModel.Task(title: "Test", date: yearDate, period: .year, status: .migrated).applying {
                $0.assignments = [
                    TaskAssignment(period: .year, date: yearDate, status: .open)
                ]
            },
            from: DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        )

        // Year assignment is same period as source, so no smaller period found
        #expect(formatted == nil)
    }
}

/// Helper for configuring model objects in tests.
private extension DataModel.Task {
    func applying(_ configure: (DataModel.Task) -> Void) -> DataModel.Task {
        configure(self)
        return self
    }
}
