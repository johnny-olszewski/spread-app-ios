import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct MigrationEligibilityTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Self.calendar.date(from: .init(year: year, month: month, day: day))!
    }

    /// Conditions: A month-desired task is open on the year spread while both month and day spreads exist.
    /// Expected: Only the month spread is the valid migration destination.
    @Test @MainActor func monthDesiredTaskStopsAtMonthSpread() async throws {
        let taskDate = makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)

        let task = DataModel.Task(
            title: "Month task",
            date: taskDate,
            period: .month,
            status: .open,
            assignments: [
                TaskAssignment(period: .year, date: taskDate, status: .open)
            ]
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: taskDate,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread, daySpread])
        )

        let monthCandidates = manager.migrationCandidates(to: monthSpread)
        let dayCandidates = manager.migrationCandidates(to: daySpread)

        #expect(monthCandidates.map(\.task.id) == [task.id])
        #expect(dayCandidates.isEmpty)
    }

    /// Conditions: A day-desired task is open on the year spread while both month and day spreads exist.
    /// Expected: Only the day spread prompts because it is the most granular valid destination.
    @Test @MainActor func dayDesiredTaskUsesMostGranularExistingDestination() async throws {
        let taskDate = makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)

        let task = DataModel.Task(
            title: "Day task",
            date: taskDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .year, date: taskDate, status: .open)
            ]
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: taskDate,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread, daySpread])
        )

        let monthCandidates = manager.migrationCandidates(to: monthSpread)
        let dayCandidates = manager.migrationCandidates(to: daySpread)

        #expect(monthCandidates.isEmpty)
        #expect(dayCandidates.map(\.task.id) == [task.id])
    }

    /// Conditions: A day-desired task is in Inbox with matching year, month, and day spreads available.
    /// Expected: Inbox is treated as the source and only the day spread prompts.
    @Test @MainActor func inboxTaskUsesMostGranularValidDestination() async throws {
        let taskDate = makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)

        let task = DataModel.Task(
            title: "Inbox task",
            date: taskDate,
            period: .day,
            status: .open
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: taskDate,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread, daySpread])
        )

        let dayCandidates = manager.migrationCandidates(to: daySpread)

        #expect(dayCandidates.count == 1)
        #expect(dayCandidates.first?.sourceKey.kind == .inbox)
        #expect(manager.migrationCandidates(to: yearSpread).isEmpty)
        #expect(manager.migrationCandidates(to: monthSpread).isEmpty)
    }

    /// Conditions: A task is complete, cancelled, or already resolved at the correct granularity.
    /// Expected: None of them are migration candidates.
    @Test @MainActor func nonOpenOrAlreadyResolvedTasksAreNotEligible() async throws {
        let taskDate = makeDate(year: 2026, month: 1, day: 10)
        let yearSpread = DataModel.Spread(period: .year, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)

        let completeTask = DataModel.Task(
            title: "Complete",
            date: taskDate,
            period: .month,
            status: .complete,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled",
            date: taskDate,
            period: .month,
            status: .cancelled,
            assignments: [TaskAssignment(period: .year, date: taskDate, status: .open)]
        )
        let resolvedTask = DataModel.Task(
            title: "Resolved",
            date: taskDate,
            period: .month,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: taskDate, status: .open)]
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: taskDate,
            taskRepository: InMemoryTaskRepository(tasks: [completeTask, cancelledTask, resolvedTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread])
        )

        #expect(manager.migrationCandidates(to: monthSpread).isEmpty)
    }

    /// Conditions: A task is in Inbox and the user moves it to a valid spread.
    /// Expected: Migration creates an open destination assignment without needing a source assignment.
    @Test @MainActor func moveTaskFromInboxCreatesDestinationAssignment() async throws {
        let taskDate = makeDate(year: 2026, month: 1, day: 10)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Inbox task",
            date: taskDate,
            period: .day,
            status: .open
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: taskDate,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread])
        )

        try await manager.moveTask(task, from: .init(kind: .inbox), to: daySpread)

        let updatedTask = manager.tasks.first { $0.id == task.id }
        #expect(updatedTask?.assignments.count == 1)
        #expect(updatedTask?.assignments.first?.status == .open)
        #expect(updatedTask?.assignments.first?.period == .day)
    }

    /// Conditions: A task prefers April 6, 2026 day, is currently open on the 2026 year spread, and the April 2026 month spread is later created.
    /// Expected: The April month spread becomes the migration destination and the year spread exposes the source-side migration affordance.
    @Test @MainActor func aprilMonthBecomesMigrationDestinationForYearHostedAprilDayTask() async throws {
        let yearDate = makeDate(year: 2026, month: 1, day: 1)
        let aprilMonthDate = makeDate(year: 2026, month: 4, day: 1)
        let aprilSixth = makeDate(year: 2026, month: 4, day: 6)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: Self.calendar)
        let aprilMonthSpread = DataModel.Spread(period: .month, date: aprilMonthDate, calendar: Self.calendar)

        let task = DataModel.Task(
            title: "Navigator year task",
            date: aprilSixth,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: yearDate, status: .open)]
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: makeDate(year: 2026, month: 3, day: 29),
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, aprilMonthSpread])
        )

        let monthCandidates = manager.migrationCandidates(to: aprilMonthSpread)
        let sourceDestination = manager.migrationDestination(for: task, on: yearSpread)

        #expect(monthCandidates.map(\.task.id) == [task.id])
        #expect(sourceDestination?.id == aprilMonthSpread.id)
    }
}
