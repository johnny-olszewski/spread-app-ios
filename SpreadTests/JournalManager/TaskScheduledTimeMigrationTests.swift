import Foundation
import Testing
@testable import Spread

/// Tests for the SPRD-298 scheduled-time keep/rebase/clear rules applied wherever a
/// task's effective assignment day/period changes — migration (`moveTask`/`migrateTask`/
/// `migrateTasksBatch`), explicit reassignment (`updateDateAndPeriod`), and moving to the
/// Inbox (`clearPreferredAssignment`). All paths delegate to the shared
/// `JournalRuleEngine.reconcileScheduledTime` helper, constructed directly with a
/// `TestTaskRepository`, mirroring `TaskCoordinatorTests`.
@MainActor
struct TaskScheduledTimeMigrationTests {

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

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - Day → Day

    /// Setup: a task scheduled at 14:30 on Jan 12 is migrated from its day spread to a day
    /// spread 3 days later (Jan 15).
    /// Expected: `scheduledTime` is rebased to 14:30 on Jan 15 (clock time preserved), and
    /// `scheduledTimeUpdatedAt` is stamped.
    @Test func testDayToDayMigrationRebasesScheduledTimePreservingClockTime() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let destinationDay = Self.makeDate(year: 2026, month: 1, day: 15)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 14, minute: 30)
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDay, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(period: .day, date: destinationDay, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", scheduledTime: scheduledTime, date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )

        try await coordinator.migrateTask(task, from: sourceSpread, to: destinationSpread)

        let expected = Self.makeDate(year: 2026, month: 1, day: 15, hour: 14, minute: 30)
        #expect(task.scheduledTime == expected)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Setup: a task scheduled at 09:00 is reassigned (not migrated via spread) from Jan 12
    /// to Jan 15 via `updateDateAndPeriod`, both day-period.
    /// Expected: `scheduledTime` rebases to 09:00 on Jan 15, and `scheduledTimeUpdatedAt` is
    /// stamped.
    @Test func testDayToDayReassignmentRebasesScheduledTime() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let destinationDay = Self.makeDate(year: 2026, month: 1, day: 15)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 9, minute: 0)
        let task = DataModel.Task(title: "Task", scheduledTime: scheduledTime, date: sourceDay, period: .day)

        try await coordinator.updateDateAndPeriod(task, newDate: destinationDay, newPeriod: .day, spreads: [])

        let expected = Self.makeDate(year: 2026, month: 1, day: 15, hour: 9, minute: 0)
        #expect(task.scheduledTime == expected)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    // MARK: - Clear on Non-Day Destinations

    /// Setup: a timed task is migrated from a day spread to a month spread.
    /// Expected: `scheduledTime` is cleared to `nil` and `scheduledTimeUpdatedAt` is stamped.
    @Test func testMigrationToMonthClearsScheduledTime() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 14, minute: 30)
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDay, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(period: .month, date: sourceDay, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", scheduledTime: scheduledTime, date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )

        try await coordinator.migrateTask(task, from: sourceSpread, to: destinationSpread)

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Setup: a timed task is migrated from a day spread to a year spread.
    /// Expected: `scheduledTime` is cleared to `nil` and `scheduledTimeUpdatedAt` is stamped.
    @Test func testMigrationToYearClearsScheduledTime() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 14, minute: 30)
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDay, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(period: .year, date: sourceDay, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", scheduledTime: scheduledTime, date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )

        try await coordinator.migrateTask(task, from: sourceSpread, to: destinationSpread)

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Setup: a timed task is migrated from a day spread to a multiday spread.
    /// Expected: `scheduledTime` is cleared to `nil` and `scheduledTimeUpdatedAt` is stamped.
    @Test func testMigrationToMultidayClearsScheduledTime() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 14, minute: 30)
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDay, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 12),
            endDate: Self.makeDate(year: 2026, month: 1, day: 18),
            calendar: Self.calendar
        )
        let task = DataModel.Task(
            title: "Task", scheduledTime: scheduledTime, date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )

        try await coordinator.migrateTask(task, from: sourceSpread, to: destinationSpread)

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Setup: a timed task with a current day assignment is explicitly reassigned to the
    /// Inbox via `clearPreferredAssignment`.
    /// Expected: `scheduledTime` is cleared to `nil` and `scheduledTimeUpdatedAt` is stamped,
    /// alongside the existing `date`/`period` clearing behavior.
    @Test func testReassignmentToInboxClearsScheduledTime() async throws {
        let (coordinator, _) = makeCoordinator()
        let day = Self.makeDate(year: 2026, month: 1, day: 12)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 14, minute: 30)
        let task = DataModel.Task(
            title: "Task", scheduledTime: scheduledTime, date: day, period: .day,
            currentAssignments: [Assignment(period: .day, date: day, status: .open)]
        )

        try await coordinator.clearPreferredAssignment(task, spreads: [])

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt != nil)
        #expect(task.date == nil)
        #expect(task.period == nil)
    }

    // MARK: - Same-Day No-Op

    /// Setup: a timed task is "migrated" from a day spread to the same day (e.g. a
    /// same-day reassignment through the review UI).
    /// Expected: `scheduledTime` and `scheduledTimeUpdatedAt` are both left completely
    /// unchanged — no timestamp stamp occurs for a no-op.
    @Test func testSameDayMigrationIsNoOp() async throws {
        let (coordinator, _) = makeCoordinator()
        let day = Self.makeDate(year: 2026, month: 1, day: 12)
        let scheduledTime = Self.makeDate(year: 2026, month: 1, day: 12, hour: 14, minute: 30)
        let sourceSpread = DataModel.Spread(period: .day, date: day, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(period: .day, date: day, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", scheduledTime: scheduledTime, date: day, period: .day,
            currentAssignments: [Assignment(period: .day, date: day, status: .open)]
        )

        try await coordinator.migrateTask(task, from: sourceSpread, to: destinationSpread)

        #expect(task.scheduledTime == scheduledTime)
        #expect(task.scheduledTimeUpdatedAt == nil)
    }

    // MARK: - Untimed Tasks

    /// Setup: an untimed task (`scheduledTime == nil`) is migrated day → month.
    /// Expected: the migration proceeds normally with no scheduled-time side effects —
    /// `scheduledTime` stays `nil` and `scheduledTimeUpdatedAt` is never stamped.
    @Test func testUntimedTaskMigratesWithNoScheduledTimeSideEffects() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDay, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(period: .month, date: sourceDay, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task", date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )

        try await coordinator.migrateTask(task, from: sourceSpread, to: destinationSpread)

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledTimeUpdatedAt == nil)
        #expect(task.currentAssignments.first?.period == .month)
    }

    /// Setup: a batch of two timed tasks assigned to the same day spread is migrated
    /// together to a month spread via `migrateTasksBatch`.
    /// Expected: both tasks' `scheduledTime` values are cleared, each stamping its own
    /// `scheduledTimeUpdatedAt`.
    @Test func testMigrateTasksBatchClearsScheduledTimeForEachTask() async throws {
        let (coordinator, _) = makeCoordinator()
        let sourceDay = Self.makeDate(year: 2026, month: 1, day: 12)
        let sourceSpread = DataModel.Spread(period: .day, date: sourceDay, calendar: Self.calendar)
        let destinationSpread = DataModel.Spread(period: .month, date: sourceDay, calendar: Self.calendar)
        let firstTask = DataModel.Task(
            title: "First", scheduledTime: Self.makeDate(year: 2026, month: 1, day: 12, hour: 8), date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )
        let secondTask = DataModel.Task(
            title: "Second", scheduledTime: Self.makeDate(year: 2026, month: 1, day: 12, hour: 20), date: sourceDay, period: .day,
            currentAssignments: [Assignment(period: .day, date: sourceDay, status: .open)]
        )

        try await coordinator.migrateTasksBatch([firstTask, secondTask], from: sourceSpread, to: destinationSpread)

        #expect(firstTask.scheduledTime == nil)
        #expect(firstTask.scheduledTimeUpdatedAt != nil)
        #expect(secondTask.scheduledTime == nil)
        #expect(secondTask.scheduledTimeUpdatedAt != nil)
    }
}
