import Foundation
import Testing
@testable import Spread

@MainActor
struct AssignmentReconcilerTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func testTaskReconcilerFallsBackToInboxByMigratingActiveAssignments() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let task = DataModel.Task(
            title: "Inbox fallback",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )

        StandardTaskAssignmentReconciler(calendar: Self.calendar)
            .reconcilePreferredAssignment(for: task, in: [])

        #expect(task.assignments.count == 1)
        #expect(task.assignments.first?.status == .migrated)
    }

    @Test func testTaskReconcilerReusesExistingDestinationAndPreservesCompleteStatus() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Complete",
            date: taskDate,
            period: .month,
            status: .complete,
            assignments: [
                TaskAssignment(period: .year, date: taskDate, status: .open),
                TaskAssignment(period: .month, date: taskDate, status: .migrated)
            ]
        )

        StandardTaskAssignmentReconciler(calendar: Self.calendar)
            .reconcilePreferredAssignment(for: task, in: [monthSpread])

        #expect(task.assignments[0].status == .migrated)
        #expect(task.assignments[1].status == .complete)
    }

    @Test func testNoteReconcilerCreatesDestinationAssignmentAfterMigratingHistory() {
        let taskDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Note",
            date: taskDate,
            period: .day,
            assignments: [NoteAssignment(period: .year, date: taskDate, status: .active)]
        )

        StandardNoteAssignmentReconciler(calendar: Self.calendar)
            .reconcilePreferredAssignment(for: note, in: [daySpread])

        #expect(note.assignments.count == 2)
        #expect(note.assignments[0].status == .migrated)
        #expect(note.assignments[1].status == .active)
        #expect(note.assignments[1].period == .day)
    }

    @Test func testNoteReconcilerReusesExistingDestinationAssignment() {
        let taskDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Note",
            date: taskDate,
            period: .day,
            assignments: [
                NoteAssignment(period: .month, date: taskDate, status: .active),
                NoteAssignment(period: .day, date: taskDate, status: .migrated)
            ]
        )

        StandardNoteAssignmentReconciler(calendar: Self.calendar)
            .reconcilePreferredAssignment(for: note, in: [daySpread])

        #expect(note.assignments[0].status == .migrated)
        #expect(note.assignments[1].status == .active)
    }
}
