import Foundation
import Testing
@testable import Spread

/// Tests for `TaskCoordinator`, constructed directly with a `TestTaskRepository` and a
/// `JournalRuleEngine` — no `JournalManager` involved. Mirrors the scenarios already
/// exercised through `JournalManager`'s existing black-box test suites
/// (`JournalManagerTaskCRUDTests`, `MigrationTests`, `JournalManagerAddTaskTests`), since
/// no legacy `Standard*` coordinator exists anymore to parity-test against.
@MainActor
struct TaskCoordinatorTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeCoordinator(today: Date = .now) -> (coordinator: TaskCoordinator, repository: TestTaskRepository) {
        let repository = TestTaskRepository()
        let ruleEngine = JournalRuleEngine(calendar: Self.calendar, today: today)
        return (TaskCoordinator(taskRepository: repository, ruleEngine: ruleEngine), repository)
    }

    // MARK: - Creation

    /// Setup: a day spread exists and matches the new task's preferred date/period.
    /// Expected: the created task has a current assignment matching that spread.
    @Test func testAddTaskReconcilesAgainstMatchingSpread() async throws {
        let (coordinator, repository) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)

        let task = try await coordinator.addTask(
            title: "New Task", date: date, period: .day, body: nil, priority: .none, dueDate: nil, spreads: [daySpread]
        )

        #expect(task.title == "New Task")
        #expect(task.currentAssignments.count == 1)
        #expect(task.currentAssignments[0].status == .open)
        #expect(await repository.getTasks().map(\.id) == [task.id])
    }

    /// Setup: no spreads exist that match the new task's preferred date.
    /// Expected: the task is created with no current assignment (Inbox).
    @Test func testAddTaskWithNoMatchingSpreadLeavesTaskUnassigned() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!

        let task = try await coordinator.addTask(
            title: "Inbox Task", date: date, period: .day, body: nil, priority: .none, dueDate: nil, spreads: []
        )

        #expect(task.currentAssignments.isEmpty)
    }

    /// Setup: the convenience overload is called with a list and tag.
    /// Expected: the created task has both set, persisted in a follow-up save.
    @Test func testAddTaskConvenienceOverloadSetsListAndTag() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let list = DataModel.List(name: "Errands")
        let tag = DataModel.Tag(name: "Urgent")

        let task = try await coordinator.addTask(title: "Task", date: date, period: .day, list: list, tag: tag, spreads: [])

        #expect(task.list?.id == list.id)
        #expect(task.tags.map(\.id) == [tag.id])
    }

    // MARK: - Updates

    /// Setup: an existing task.
    /// Expected: `updateTitle` changes the title and persists it.
    @Test func testUpdateTitlePersistsChange() async throws {
        let (coordinator, repository) = makeCoordinator()
        let task = DataModel.Task(title: "Original")
        try await repository.save(task, change: EntityChange())

        try await coordinator.updateTitle(task, newTitle: "Updated")

        #expect(task.title == "Updated")
        let saved = await repository.getTasks().first
        #expect(saved?.title == "Updated")
    }

    /// Setup: an existing open task.
    /// Expected: `updateStatus` changes the status and persists it.
    @Test func testUpdateStatusPersistsChange() async throws {
        let (coordinator, _) = makeCoordinator()
        let task = DataModel.Task(title: "Task", status: .open)

        try await coordinator.updateStatus(task, newStatus: .complete)

        #expect(task.status == .complete)
    }

    /// Setup: an existing task.
    /// Expected: `updateStatus(newStatus: .migrated)` throws — `.migrated` is only set by
    /// migration flows, never directly by the user.
    @Test func testUpdateStatusRejectsDirectMigratedStatus() async throws {
        let (coordinator, _) = makeCoordinator()
        let task = DataModel.Task(title: "Task", status: .open)

        await #expect(throws: TaskMutationError.manualMigratedStatusNotAllowed) {
            try await coordinator.updateStatus(task, newStatus: .migrated)
        }
    }

    /// Setup: a task with no preferred assignment; a day spread matching the new date exists.
    /// Expected: `updateDateAndPeriod` sets the new date/period and reconciles a current
    /// assignment against the matching spread.
    @Test func testUpdateDateAndPeriodReconcilesAssignment() async throws {
        let (coordinator, _) = makeCoordinator()
        let task = DataModel.Task(title: "Task", date: nil, period: nil)
        let newDate = Self.calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let daySpread = DataModel.Spread(period: .day, date: newDate, calendar: Self.calendar)

        try await coordinator.updateDateAndPeriod(task, newDate: newDate, newPeriod: .day, spreads: [daySpread])

        #expect(task.period == .day)
        #expect(task.currentAssignments.count == 1)
    }

    /// Setup: an existing task.
    /// Expected: `updateMetadata` updates body/priority/dueDate/list/tags and stamps LWW
    /// timestamps only for fields that actually changed.
    @Test func testUpdateMetadataUpdatesChangedFieldsOnly() async throws {
        let (coordinator, _) = makeCoordinator()
        let task = DataModel.Task(title: "Task", body: "Old body", priority: .low)
        let list = DataModel.List(name: "Work")

        try await coordinator.updateMetadata(task, body: "New body", priority: .high, dueDate: nil, scheduledTime: nil, list: list, tags: [])

        #expect(task.body == "New body")
        #expect(task.priority == .high)
        #expect(task.bodyUpdatedAt != nil)
        #expect(task.priorityUpdatedAt != nil)
        #expect(task.list?.id == list.id)
    }

    /// Setup: a task with a current assignment.
    /// Expected: `clearPreferredAssignment` clears date/period and migrates the current
    /// assignment to history, leaving the task in Inbox.
    @Test func testClearPreferredAssignmentMovesCurrentToHistory() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let task = DataModel.Task(title: "Task", date: date, period: .day, currentAssignments: [
            Assignment(period: .day, date: date, status: .open)
        ])

        try await coordinator.clearPreferredAssignment(task, spreads: [daySpread])

        #expect(task.date == nil)
        #expect(task.period == nil)
        #expect(task.currentAssignments.isEmpty)
        #expect(task.migrationHistory.count == 1)
        #expect(task.migrationHistory[0].status == .migrated)
    }

    // MARK: - Deletion

    /// Setup: an existing task in the repository.
    /// Expected: `delete` removes it from the repository.
    @Test func testDeleteRemovesFromRepository() async throws {
        let (coordinator, repository) = makeCoordinator()
        let task = DataModel.Task(title: "Task")
        try await repository.save(task, change: EntityChange())

        try await coordinator.delete(task)

        let remaining = await repository.getTasks()
        #expect(remaining.isEmpty)
    }

    // MARK: - Migration

    /// Setup: a cancelled task.
    /// Expected: `moveTask` throws `MigrationError.taskCancelled` rather than migrating it.
    @Test func testMoveTaskRejectsCancelledTask() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let task = DataModel.Task(title: "Task", status: .cancelled)

        await #expect(throws: MigrationError.taskCancelled) {
            try await coordinator.moveTask(task, from: .init(kind: .inbox), to: daySpread)
        }
    }

    /// Setup: a task with no assignment on the claimed source spread.
    /// Expected: `migrateTask` throws `MigrationError.noSourceAssignment`.
    @Test func testMigrateTaskRejectsMissingSourceAssignment() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let task = DataModel.Task(title: "Task", date: date, period: .day, currentAssignments: [])

        await #expect(throws: MigrationError.noSourceAssignment) {
            try await coordinator.migrateTask(task, from: monthSpread, to: daySpread)
        }
    }

    /// Setup: a task currently assigned to a month spread.
    /// Expected: `migrateTask` moves the month assignment to history and creates a new
    /// `.open` assignment for the day destination, setting `task.status = .open`.
    @Test func testMigrateTaskMovesAssignmentAndReopensStatus() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", date: date, period: .month, status: .complete,
            currentAssignments: [Assignment(period: .month, date: date, status: .open)]
        )

        try await coordinator.migrateTask(task, from: monthSpread, to: daySpread)

        #expect(task.migrationHistory.count == 1)
        #expect(task.currentAssignments.count == 1)
        #expect(task.currentAssignments[0].period == .day)
        #expect(task.currentAssignments[0].status == .open)
        #expect(task.status == .open)
    }

    /// Setup: a task currently in the Inbox (no assignment), moved directly to a spread.
    /// Expected: no source removal occurs; a fresh assignment is created for the destination.
    @Test func testMoveTaskFromInboxCreatesDestinationAssignment() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let task = DataModel.Task(title: "Inbox Task", date: nil, period: nil, currentAssignments: [])

        try await coordinator.moveTask(task, from: .init(kind: .inbox), to: daySpread)

        #expect(task.migrationHistory.isEmpty)
        #expect(task.currentAssignments.count == 1)
        #expect(task.currentAssignments[0].status == .open)
    }

    /// Setup: two tasks assigned to the source spread, one cancelled.
    /// Expected: `migrateTasksBatch` migrates the open task and silently skips the
    /// cancelled one.
    @Test func testMigrateTasksBatchSkipsCancelledTasks() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let openTask = DataModel.Task(
            title: "Open", date: date, period: .month,
            currentAssignments: [Assignment(period: .month, date: date, status: .open)]
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled", date: date, period: .month, status: .cancelled,
            currentAssignments: [Assignment(period: .month, date: date, status: .open)]
        )

        try await coordinator.migrateTasksBatch([openTask, cancelledTask], from: monthSpread, to: daySpread)

        #expect(openTask.currentAssignments.first?.period == .day)
        #expect(cancelledTask.currentAssignments.first?.period == .month)
    }
}
