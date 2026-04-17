import Foundation
import Testing
@testable import Spread

@Suite(.serialized) @MainActor
struct SpreadDeletionPlannerTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    private let planner = StandardSpreadDeletionPlanner(calendar: Self.calendar)

    @Test func choosesImmediateParentBeforeGrandparent() {
        let year = DataModel.Spread(period: .year, date: Self.testDate, calendar: Self.calendar)
        let month = DataModel.Spread(period: .month, date: Self.testDate, calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "task",
            date: Self.testDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: Self.testDate, status: .open)]
        )

        let plan = planner.makePlan(for: day, spreads: [year, month, day], tasks: [task], notes: [])

        #expect(plan.parentSpread?.id == month.id)
        #expect(plan.taskPlans.count == 1)
        #expect(plan.taskPlans[0].replacementAssignment?.period == .month)
    }

    @Test func fallsBackToInboxWhenNoParentSpreadExists() {
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "task",
            date: Self.testDate,
            period: .day,
            status: .complete,
            assignments: [TaskAssignment(period: .day, date: Self.testDate, status: .complete)]
        )

        let plan = planner.makePlan(for: day, spreads: [day], tasks: [task], notes: [])

        #expect(plan.parentSpread == nil)
        #expect(plan.taskPlans[0].replacementAssignment == nil)
        #expect(plan.taskPlans[0].replacementAssignmentIndex == nil)
        #expect(plan.taskPlans[0].preservedStatus == .complete)
    }

    @Test func reusesExistingParentAssignmentAndPreservesMigratedHistory() {
        let month = DataModel.Spread(period: .month, date: Self.testDate, calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "task",
            date: Self.testDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .day, date: Self.testDate, status: .open),
                TaskAssignment(period: .month, date: Self.testDate, status: .migrated)
            ]
        )
        let note = DataModel.Note(
            title: "note",
            date: Self.testDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .day, date: Self.testDate, status: .active),
                NoteAssignment(period: .month, date: Self.testDate, status: .migrated)
            ]
        )

        let plan = planner.makePlan(for: day, spreads: [month, day], tasks: [task], notes: [note])

        #expect(plan.taskPlans[0].replacementAssignmentIndex == 1)
        #expect(plan.taskPlans[0].replacementAssignment == nil)
        #expect(plan.notePlans[0].replacementAssignmentIndex == 1)
        #expect(plan.notePlans[0].replacementAssignment == nil)
    }

    @Test func multidayDeletionProducesNoReassignmentPlans() {
        let multiday = DataModel.Spread(
            startDate: Self.testDate,
            endDate: Self.calendar.date(byAdding: .day, value: 2, to: Self.testDate)!,
            calendar: Self.calendar
        )
        let task = DataModel.Task(
            title: "task",
            date: Self.testDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: Self.testDate, status: .open)]
        )

        let plan = planner.makePlan(for: multiday, spreads: [multiday], tasks: [task], notes: [])

        #expect(plan.parentSpread == nil)
        #expect(plan.taskPlans.isEmpty)
        #expect(plan.notePlans.isEmpty)
    }
}
