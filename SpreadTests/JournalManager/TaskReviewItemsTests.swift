import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct TaskReviewItemsTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    // MARK: - inFlightTaskItems status gating

    /// Setup: five tasks sharing the same day assignment, one per `EntryStatus` case
    /// (`.open`, `.inFlight`, `.complete`, `.cancelled`, `.migrated`).
    /// Expected: `inFlightTaskItems` collects exactly the `.inFlight` task and none of the
    /// other statuses.
    @Test @MainActor func inFlightTaskItemsCollectsOnlyInFlightTasks() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        func task(_ title: String, status: EntryStatus) -> DataModel.Task {
            DataModel.Task(
                title: title,
                date: dayDate,
                period: .day,
                status: status,
                currentAssignments: [Assignment(period: .day, date: dayDate, status: status)]
            )
        }

        let openTask = task("Open", status: .open)
        let inFlightTask = task("In flight", status: .inFlight)
        let completeTask = task("Complete", status: .complete)
        let cancelledTask = task("Cancelled", status: .cancelled)
        let migratedTask = task("Migrated", status: .migrated)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: TestTaskRepository(
                tasks: [openTask, inFlightTask, completeTask, cancelledTask, migratedTask]
            )
        )

        #expect(manager.inFlightTaskItems.map(\.task.id) == [inFlightTask.id])
    }

    // MARK: - inFlightTaskItems source resolution

    /// Setup: an in-flight task assigned to a day spread that exists in the journal, alongside
    /// an unassigned in-flight task.
    /// Expected: the assigned task resolves a `.spread` source key carrying that spread's id;
    /// the unassigned task resolves `.inbox`.
    @Test @MainActor func inFlightTaskItemsResolveSpreadOrInboxSourceKey() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        let assignedTask = DataModel.Task(
            title: "Assigned in flight",
            date: dayDate,
            period: .day,
            status: .inFlight,
            currentAssignments: [Assignment(period: .day, date: dayDate, status: .inFlight)]
        )
        let unassignedTask = DataModel.Task(
            title: "Unassigned in flight",
            date: dayDate,
            period: .day,
            status: .inFlight
        )
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: TestTaskRepository(tasks: [assignedTask, unassignedTask]),
            spreadRepository: TestSpreadRepository(spreads: [daySpread])
        )

        let items = manager.inFlightTaskItems
        let assignedItem = try #require(items.first { $0.task.id == assignedTask.id })
        let unassignedItem = try #require(items.first { $0.task.id == unassignedTask.id })

        guard case .spread(let id, _, _) = assignedItem.sourceKey.kind else {
            Issue.record("Expected a spread source key")
            return
        }
        #expect(id == daySpread.id)
        #expect(unassignedItem.sourceKey.kind == .inbox)
    }

    // MARK: - reviewInboxTasks

    /// Setup: an unassigned open task, an unassigned note, and an unassigned in-flight task —
    /// none of them have any spread assignment.
    /// Expected: `reviewInboxTasks` includes only the open task (notes are never Inbox-eligible;
    /// `.inFlight` tasks are excluded so they don't double-appear). The in-flight task instead
    /// shows up in `inFlightTaskItems` — the no-double-appearance rule, asserted on both sides.
    @Test @MainActor func reviewInboxTasksExcludesNotesAndInFlightTasks() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        let openTask = DataModel.Task(
            title: "Unassigned open",
            date: dayDate,
            period: .day,
            status: .open
        )
        let inFlightTask = DataModel.Task(
            title: "Unassigned in flight",
            date: dayDate,
            period: .day,
            status: .inFlight
        )
        let note = DataModel.Note(
            title: "Unassigned note",
            date: dayDate,
            period: .day,
            status: .active
        )

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: TestTaskRepository(tasks: [openTask, inFlightTask]),
            noteRepository: TestNoteRepository(notes: [note])
        )

        #expect(manager.reviewInboxTasks.map(\.id) == [openTask.id])
        #expect(manager.inFlightTaskItems.map(\.task.id) == [inFlightTask.id])
    }

    // MARK: - Counts

    /// Setup: two in-flight tasks (one assigned, one unassigned) plus an unrelated open task.
    /// Expected: `inFlightTaskCount` matches `inFlightTaskItems.count`.
    @Test @MainActor func inFlightTaskCountMatchesInFlightTaskItemsCount() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        let assignedInFlightTask = DataModel.Task(
            title: "Assigned in flight",
            date: dayDate,
            period: .day,
            status: .inFlight,
            currentAssignments: [Assignment(period: .day, date: dayDate, status: .inFlight)]
        )
        let unassignedInFlightTask = DataModel.Task(
            title: "Unassigned in flight",
            date: dayDate,
            period: .day,
            status: .inFlight
        )
        let openTask = DataModel.Task(
            title: "Open",
            date: dayDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: TestTaskRepository(tasks: [assignedInFlightTask, unassignedInFlightTask, openTask]),
            spreadRepository: TestSpreadRepository(spreads: [daySpread])
        )

        #expect(manager.inFlightTaskCount == manager.inFlightTaskItems.count)
        #expect(manager.inFlightTaskCount == 2)
    }
}
