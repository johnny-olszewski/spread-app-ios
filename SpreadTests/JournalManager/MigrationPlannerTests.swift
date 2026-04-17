import Foundation
import Testing
@testable import Spread

@MainActor
struct MigrationPlannerTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func testPlannerUsesMostGranularValidDestination() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Day task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )

        let planner = StandardMigrationPlanner(calendar: Self.calendar)

        let monthCandidates = planner.migrationCandidates(
            tasks: [task],
            spreads: [yearSpread, monthSpread, daySpread],
            bujoMode: .conventional,
            to: monthSpread
        )
        let dayCandidates = planner.migrationCandidates(
            tasks: [task],
            spreads: [yearSpread, monthSpread, daySpread],
            bujoMode: .conventional,
            to: daySpread
        )

        #expect(monthCandidates.isEmpty)
        #expect(dayCandidates.map(\.task.id) == [task.id])
        #expect(dayCandidates.first?.sourceSpread?.id == yearSpread.id)
    }

    @Test func testParentHierarchyCandidatesExcludeInboxAndSortAlphabetically() {
        let taskDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)

        let yearTask = DataModel.Task(
            title: "Zulu",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )
        let monthTask = DataModel.Task(
            title: "Alpha",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: taskDate, status: .open)]
        )
        let inboxTask = DataModel.Task(
            title: "Inbox",
            date: taskDate,
            period: .day,
            status: .open
        )

        let planner = StandardMigrationPlanner(calendar: Self.calendar)
        let candidates = planner.parentHierarchyMigrationCandidates(
            tasks: [yearTask, monthTask, inboxTask],
            spreads: [yearSpread, monthSpread, daySpread],
            bujoMode: .conventional,
            to: daySpread
        )

        #expect(candidates.map(\.task.title) == ["Alpha", "Zulu"])
        #expect(candidates.allSatisfy { $0.sourceSpread != nil })
    }

    @Test func testCurrentDisplayedSpreadCanDifferFromCurrentDestinationSpread() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Mixed status",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: taskDate, status: .open),
                TaskAssignment(period: .day, date: taskDate, status: .complete)
            ]
        )

        let planner = StandardMigrationPlanner(calendar: Self.calendar)

        let destination = planner.currentDestinationSpread(
            for: task,
            spreads: [monthSpread, daySpread],
            excluding: nil
        )
        let displayed = planner.currentDisplayedSpread(
            for: task,
            spreads: [monthSpread, daySpread],
            excluding: nil
        )

        #expect(destination?.id == monthSpread.id)
        #expect(displayed?.id == daySpread.id)
    }

    @Test func testMigrationDestinationRequiresConventionalSourceAssignment() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Move me",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )

        let planner = StandardMigrationPlanner(calendar: Self.calendar)

        let conventionalDestination = planner.migrationDestination(
            for: task,
            on: yearSpread,
            spreads: [yearSpread, daySpread],
            bujoMode: .conventional
        )
        let traditionalDestination = planner.migrationDestination(
            for: task,
            on: yearSpread,
            spreads: [yearSpread, daySpread],
            bujoMode: .traditional
        )

        #expect(conventionalDestination?.id == daySpread.id)
        #expect(traditionalDestination == nil)
    }
}
