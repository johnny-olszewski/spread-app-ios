import Foundation
import Testing
@testable import Spread

@MainActor
struct OverdueEvaluatorTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func testEvaluatorReturnsInboxSourceForOverdueUnassignedDayTask() {
        let today = Self.makeDate(year: 2026, month: 4, day: 12)
        let task = DataModel.Task(
            title: "Inbox overdue",
            date: Self.makeDate(year: 2026, month: 4, day: 11),
            period: .day,
            status: .open
        )

        let evaluator = StandardOverdueEvaluator(
            calendar: Self.calendar,
            today: today,
            migrationPlanner: StandardMigrationPlanner(calendar: Self.calendar)
        )

        let items = evaluator.overdueTaskItems(tasks: [task], spreads: [])

        #expect(items.map(\.task.id) == [task.id])
        #expect(items.first?.sourceKey.id == "inbox")
    }

    @Test func testEvaluatorUsesCurrentDestinationSpreadAsOverdueSource() {
        let today = Self.makeDate(year: 2026, month: 5, day: 3)
        let monthDate = Self.makeDate(year: 2026, month: 4, day: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Spread overdue",
            date: Self.makeDate(year: 2026, month: 5, day: 20),
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: monthDate, status: .open)]
        )

        let evaluator = StandardOverdueEvaluator(
            calendar: Self.calendar,
            today: today,
            migrationPlanner: StandardMigrationPlanner(calendar: Self.calendar)
        )

        let items = evaluator.overdueTaskItems(tasks: [task], spreads: [monthSpread])

        #expect(items.first?.sourceKey.id == "spread-\(monthSpread.id.uuidString)")
    }

    @Test func testEvaluatorUsesMonthAndYearBoundaryRules() {
        let today = Self.makeDate(year: 2026, month: 5, day: 1)
        let overdueMonthTask = DataModel.Task(
            title: "Month overdue",
            date: Self.makeDate(year: 2026, month: 4, day: 10),
            period: .month,
            status: .open
        )
        let notYetOverdueYearTask = DataModel.Task(
            title: "Year active",
            date: Self.makeDate(year: 2026, month: 1, day: 1),
            period: .year,
            status: .open
        )

        let evaluator = StandardOverdueEvaluator(
            calendar: Self.calendar,
            today: today,
            migrationPlanner: StandardMigrationPlanner(calendar: Self.calendar)
        )

        let items = evaluator.overdueTaskItems(
            tasks: [overdueMonthTask, notYetOverdueYearTask],
            spreads: []
        )

        #expect(items.map(\.task.id) == [overdueMonthTask.id])
    }

    @Test func testEvaluatorExcludesCompletedCancelledAndMultidayTasks() {
        let today = Self.makeDate(year: 2026, month: 4, day: 12)
        let completeTask = DataModel.Task(
            title: "Complete",
            date: Self.makeDate(year: 2026, month: 4, day: 10),
            period: .day,
            status: .complete
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled",
            date: Self.makeDate(year: 2026, month: 4, day: 10),
            period: .day,
            status: .cancelled
        )
        let multidayTask = DataModel.Task(
            title: "Multiday",
            date: Self.makeDate(year: 2026, month: 4, day: 1),
            period: .multiday,
            status: .open
        )

        let evaluator = StandardOverdueEvaluator(
            calendar: Self.calendar,
            today: today,
            migrationPlanner: StandardMigrationPlanner(calendar: Self.calendar)
        )

        let items = evaluator.overdueTaskItems(
            tasks: [completeTask, cancelledTask, multidayTask],
            spreads: []
        )

        #expect(items.isEmpty)
    }
}
