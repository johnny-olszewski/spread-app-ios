import Foundation
import Testing
@testable import Spread

@Suite("Multiday Aggregation Tests")
@MainActor
struct MultidayAggregationTests {
    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeManager(
        tasks: [DataModel.Task] = [],
        notes: [DataModel.Note] = [],
        spreads: [DataModel.Spread] = []
    ) async throws -> JournalManager {
        try await JournalManager.make(
            calendar: Self.testCalendar,
            taskRepository: InMemoryTaskRepository(tasks: tasks),
            spreadRepository: InMemorySpreadRepository(spreads: spreads),
            noteRepository: InMemoryNoteRepository(notes: notes)
        )
    }

    @Test("Multiday aggregation includes tasks explicitly assigned to the spread")
    func explicitTaskAssignmentsAppearOnTheirMultidaySpread() async throws {
        let calendar = Self.testCalendar
        let spread = DataModel.Spread(
            startDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 28))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 3))!,
            calendar: calendar
        )

        let assignedTask = DataModel.Task(
            title: "Assigned",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 30))!,
            period: .multiday,
            assignments: [
                TaskAssignment(period: .multiday, date: spread.date, spreadID: spread.id, status: .open)
            ]
        )
        let unrelatedTask = DataModel.Task(
            title: "Unrelated",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!,
            period: .day
        )

        let manager = try await makeManager(tasks: [assignedTask, unrelatedTask], spreads: [spread])
        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.map(\.id) == [assignedTask.id])
    }

    @Test("Multiday aggregation includes notes explicitly assigned to the spread")
    func explicitNoteAssignmentsAppearOnTheirMultidaySpread() async throws {
        let calendar = Self.testCalendar
        let spread = DataModel.Spread(
            startDate: calendar.date(from: DateComponents(year: 2025, month: 12, day: 29))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!,
            calendar: calendar
        )

        let assignedNote = DataModel.Note(
            title: "Assigned note",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            period: .multiday,
            assignments: [
                NoteAssignment(period: .multiday, date: spread.date, spreadID: spread.id, status: .active)
            ]
        )
        let unrelatedNote = DataModel.Note(
            title: "Unrelated note",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            period: .day
        )

        let manager = try await makeManager(notes: [assignedNote, unrelatedNote], spreads: [spread])
        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.notes.map(\.id) == [assignedNote.id])
    }

    @Test("Multiday aggregation does not infer membership from preferred dates alone")
    func preferredDatesAloneDoNotPopulateMultidaySpreads() async throws {
        let calendar = Self.testCalendar
        let spread = DataModel.Spread(
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            calendar: calendar
        )

        let inRangeTask = DataModel.Task(
            title: "Preferred only",
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!,
            period: .day
        )

        let manager = try await makeManager(tasks: [inRangeTask], spreads: [spread])
        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.isEmpty != false)
    }

    @Test("Cancelled tasks remain visible when explicitly assigned to the spread")
    func cancelledTasksDoNotAppearWithoutActiveMultidayOwnership() async throws {
        let calendar = Self.testCalendar
        let spread = DataModel.Spread(
            startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 7))!,
            calendar: calendar
        )

        let openTask = DataModel.Task(
            title: "Open task",
            date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 3))!,
            period: .multiday,
            status: .open,
            assignments: [
                TaskAssignment(period: .multiday, date: spread.date, spreadID: spread.id, status: .open)
            ]
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled task",
            date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))!,
            period: .multiday,
            status: .cancelled,
            assignments: [
                TaskAssignment(period: .multiday, date: spread.date, spreadID: spread.id, status: .cancelled)
            ]
        )

        let manager = try await makeManager(tasks: [openTask, cancelledTask], spreads: [spread])
        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.map(\.id) == [openTask.id, cancelledTask.id])
    }
}
