import Foundation
import Testing
@testable import Spread

@Suite(.serialized) @MainActor
struct EntryMigrationCoordinatorTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    @Test func taskMigrationFromInboxCreatesDestinationAssignment() async throws {
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let task = DataModel.Task(title: "task", date: Self.testDate, period: .day, status: .open, assignments: [])
        let repository = InMemoryTaskRepository(tasks: [task])
        let coordinator = StandardTaskMigrationCoordinator(
            taskRepository: repository,
            logger: LoggerAdapter(info: { _ in })
        )

        let result = try await coordinator.moveTask(
            task,
            from: TaskReviewSourceKey(kind: .inbox),
            to: day,
            calendar: Self.calendar
        )

        let updated = try #require(result.tasks.first)
        #expect(updated.assignments.contains(where: { $0.period == .day && $0.status == .open }))
        #expect(result.mutation.kind == .taskChanged(id: task.id))
    }

    @Test func taskBatchMigrationSkipsCancelledTasks() async throws {
        let month = DataModel.Spread(period: .month, date: Self.testDate, calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let openTask = DataModel.Task(
            title: "open",
            date: Self.testDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: Self.testDate, status: .open)]
        )
        let cancelledTask = DataModel.Task(
            title: "cancelled",
            date: Self.testDate,
            period: .day,
            status: .cancelled,
            assignments: [TaskAssignment(period: .month, date: Self.testDate, status: .open)]
        )
        let repository = InMemoryTaskRepository(tasks: [openTask, cancelledTask])
        let coordinator = StandardTaskMigrationCoordinator(
            taskRepository: repository,
            logger: LoggerAdapter(info: { _ in })
        )

        let result = try await coordinator.migrateTasksBatch(
            [openTask, cancelledTask],
            from: month,
            to: day,
            calendar: Self.calendar
        )

        let migratedOpenTask = try #require(result.tasks.first(where: { $0.id == openTask.id }))
        let untouchedCancelledTask = try #require(result.tasks.first(where: { $0.id == cancelledTask.id }))
        #expect(result.migratedAny)
        #expect(migratedOpenTask.assignments.contains(where: { $0.period == .day && $0.status == .open }))
        #expect(untouchedCancelledTask.assignments.contains(where: { $0.period == .month && $0.status == .open }))
        #expect(!untouchedCancelledTask.assignments.contains(where: { $0.period == .day }))
    }

    @Test func noteMigrationReusesExistingDestinationAssignment() async throws {
        let month = DataModel.Spread(period: .month, date: Self.testDate, calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "note",
            date: Self.testDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .month, date: Self.testDate, status: .active),
                NoteAssignment(period: .day, date: Self.testDate, status: .migrated)
            ]
        )
        let repository = InMemoryNoteRepository(notes: [note])
        let coordinator = StandardNoteMigrationCoordinator(
            noteRepository: repository,
            logger: LoggerAdapter(info: { _ in })
        )

        let result = try await coordinator.migrateNote(
            note,
            from: month,
            to: day,
            calendar: Self.calendar
        )

        let updated = try #require(result.notes.first)
        #expect(updated.assignments.first(where: { $0.period == .month })?.status == .migrated)
        #expect(updated.assignments.first(where: { $0.period == .day })?.status == .active)
        #expect(result.mutation.kind == .noteChanged(id: note.id))
    }
}
