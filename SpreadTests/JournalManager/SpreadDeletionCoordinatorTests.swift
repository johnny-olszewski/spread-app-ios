import Foundation
import Testing
@testable import Spread

@Suite(.serialized) @MainActor
struct SpreadDeletionCoordinatorTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    @Test func deletesSpreadAndPersistsReassignedEntries() async throws {
        let month = DataModel.Spread(period: .month, date: Self.testDate, calendar: Self.calendar)
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "task",
            date: Self.testDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: Self.testDate, status: .open)]
        )
        let note = DataModel.Note(
            title: "note",
            date: Self.testDate,
            period: .day,
            status: .active,
            assignments: [NoteAssignment(period: .day, date: Self.testDate, status: .active)]
        )

        let taskRepository = InMemoryTaskRepository(tasks: [task])
        let noteRepository = InMemoryNoteRepository(notes: [note])
        let spreadRepository = InMemorySpreadRepository(spreads: [month, day])
        let coordinator = StandardSpreadDeletionCoordinator(
            planner: StandardSpreadDeletionPlanner(calendar: Self.calendar),
            spreadRepository: spreadRepository,
            taskRepository: taskRepository,
            noteRepository: noteRepository,
            logger: LoggerAdapter(info: { _ in })
        )

        let result = try await coordinator.deleteSpread(
            day,
            spreads: [month, day],
            tasks: [task],
            notes: [note]
        )

        #expect(result.spreads.count == 1)
        #expect(result.spreads.first?.id == month.id)
        #expect(result.plan.taskPlans.count == 1)
        #expect(result.plan.notePlans.count == 1)

        let savedTask = await taskRepository.getTasks().first!
        let savedNote = await noteRepository.getNotes().first!
        #expect(savedTask.assignments.contains(where: { $0.period == .month && $0.status == .open }))
        #expect(savedTask.assignments.contains(where: { $0.period == .day && $0.status == .migrated }))
        #expect(savedNote.assignments.contains(where: { $0.period == .month && $0.status == .active }))
        #expect(savedNote.assignments.contains(where: { $0.period == .day && $0.status == .migrated }))
    }

    @Test func deletingSpreadWithoutParentLeavesEntriesInInboxState() async throws {
        let day = DataModel.Spread(period: .day, date: Self.testDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "task",
            date: Self.testDate,
            period: .day,
            status: .complete,
            assignments: [TaskAssignment(period: .day, date: Self.testDate, status: .complete)]
        )

        let taskRepository = InMemoryTaskRepository(tasks: [task])
        let coordinator = StandardSpreadDeletionCoordinator(
            planner: StandardSpreadDeletionPlanner(calendar: Self.calendar),
            spreadRepository: InMemorySpreadRepository(spreads: [day]),
            taskRepository: taskRepository,
            noteRepository: InMemoryNoteRepository(),
            logger: LoggerAdapter(info: { _ in })
        )

        _ = try await coordinator.deleteSpread(day, spreads: [day], tasks: [task], notes: [])

        let savedTask = await taskRepository.getTasks().first!
        #expect(savedTask.assignments.count == 1)
        #expect(savedTask.assignments[0].status == .migrated)
    }
}
