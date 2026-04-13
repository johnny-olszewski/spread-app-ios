import Foundation
import Testing
@testable import Spread

@MainActor
struct EntryMutationCoordinatorTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func testTaskCoordinatorCreatesTaskAssignedToBestSpread() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let repository = InMemoryTaskRepository()
        let coordinator = StandardTaskMutationCoordinator(
            taskRepository: repository,
            taskAssignmentReconciler: StandardTaskAssignmentReconciler(calendar: Self.calendar),
            logger: LoggerAdapter(info: { _ in }),
            calendar: Self.calendar
        )

        let result = try await coordinator.createTask(
            title: "Created",
            date: taskDate,
            period: .day,
            calendar: Self.calendar,
            spreads: [daySpread]
        )

        #expect(result.task.assignments.count == 1)
        #expect(result.task.assignments.first?.period == .day)
        #expect(result.tasks.map(\.id) == [result.task.id])
    }

    @Test func testTaskCoordinatorTraditionalMigrationClearsAssignmentsAndRebuildsDestination() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let destinationDate = Self.makeDate(year: 2026, month: 2, day: 2)
        let daySpread = DataModel.Spread(period: .day, date: destinationDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Traditional",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )
        let repository = InMemoryTaskRepository(tasks: [task])
        let coordinator = StandardTaskMutationCoordinator(
            taskRepository: repository,
            taskAssignmentReconciler: StandardTaskAssignmentReconciler(calendar: Self.calendar),
            logger: LoggerAdapter(info: { _ in }),
            calendar: Self.calendar
        )

        let result = try await coordinator.traditionalMigrateTask(
            task,
            newDate: destinationDate,
            newPeriod: .day,
            calendar: Self.calendar,
            spreads: [daySpread]
        )

        let updatedTask = try #require(result.tasks.first)
        #expect(updatedTask.assignments.count == 1)
        #expect(updatedTask.assignments.first?.period == .day)
        #expect(updatedTask.assignments.first?.date == daySpread.date)
        #expect(result.mutation.kind == .taskChanged(id: task.id))
    }

    @Test func testNoteCoordinatorCreatesInboxNoteWhenNoSpreadMatches() async throws {
        let noteDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let repository = InMemoryNoteRepository()
        let coordinator = StandardNoteMutationCoordinator(
            noteRepository: repository,
            noteAssignmentReconciler: StandardNoteAssignmentReconciler(calendar: Self.calendar),
            logger: LoggerAdapter(info: { _ in }),
            calendar: Self.calendar
        )

        let result = try await coordinator.createNote(
            title: "Inbox note",
            content: "",
            date: noteDate,
            period: .day,
            calendar: Self.calendar,
            spreads: []
        )

        #expect(result.note.assignments.isEmpty)
        #expect(result.notes.map(\.id) == [result.note.id])
    }

    @Test func testNoteCoordinatorUpdateDateUsesReconciler() async throws {
        let originalDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let destinationDate = Self.makeDate(year: 2026, month: 1, day: 11)
        let destinationSpread = DataModel.Spread(period: .day, date: destinationDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Move note",
            date: originalDate,
            period: .day,
            assignments: [NoteAssignment(period: .month, date: originalDate, status: .active)]
        )
        let repository = InMemoryNoteRepository(notes: [note])
        let coordinator = StandardNoteMutationCoordinator(
            noteRepository: repository,
            noteAssignmentReconciler: StandardNoteAssignmentReconciler(calendar: Self.calendar),
            logger: LoggerAdapter(info: { _ in }),
            calendar: Self.calendar
        )

        let result = try await coordinator.updateNoteDateAndPeriod(
            note,
            newDate: destinationDate,
            newPeriod: .day,
            calendar: Self.calendar,
            spreads: [destinationSpread]
        )

        let updatedNote = try #require(result.notes.first)
        #expect(updatedNote.assignments.contains(where: { $0.period == .day && $0.status == .active }))
        #expect(updatedNote.assignments.contains(where: { $0.period == .month && $0.status == .migrated }))
        #expect(result.mutation.kind == .noteChanged(id: note.id))
    }
}
