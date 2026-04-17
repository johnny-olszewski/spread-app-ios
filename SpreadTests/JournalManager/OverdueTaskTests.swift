import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct OverdueTaskTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    /// Setup: one open day assignment before today, one open month assignment in the current month.
    /// Expected: only the day task counts as overdue before the month has ended.
    @Test @MainActor func dayAssignmentsBecomeOverdueBeforeMonthAssignments() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let dayDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let monthDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let overdueDayTask = DataModel.Task(
            title: "Day task",
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )
        let currentMonthTask = DataModel.Task(
            title: "Month task",
            date: monthDate,
            period: .month,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: monthDate, status: .open)]
        )

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: [overdueDayTask, currentMonthTask])
        )

        #expect(manager.overdueTaskCount == 1)
        #expect(manager.overdueTaskItems.map(\.task.id) == [overdueDayTask.id])
    }

    /// Setup: an open month task from January and an open year task from 2025, viewed on February 1, 2026.
    /// Expected: both tasks count as overdue once their assignment periods have fully passed.
    @Test @MainActor func monthAndYearAssignmentsBecomeOverdueAfterTheirPeriodsPass() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!

        let monthTask = DataModel.Task(
            title: "Month task",
            date: january,
            period: .month,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: january, status: .open)]
        )
        let yearTask = DataModel.Task(
            title: "Year task",
            date: lastYear,
            period: .year,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: lastYear, status: .open)]
        )

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: [monthTask, yearTask])
        )

        #expect(manager.overdueTaskCount == 2)
        #expect(Set(manager.overdueTaskItems.map(\.task.id)) == Set([monthTask.id, yearTask.id]))
    }

    /// Setup: one Inbox month task whose preferred month already ended, plus a completed day task.
    /// Expected: the Inbox task is overdue by desired assignment fallback and the completed task is excluded.
    @Test @MainActor func inboxFallbackUsesDesiredAssignmentAndExcludesResolvedTasks() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let resolvedDay = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        let inboxTask = DataModel.Task(
            title: "Inbox month task",
            date: january,
            period: .month,
            status: .open
        )
        let completedTask = DataModel.Task(
            title: "Completed day task",
            date: resolvedDay,
            period: .day,
            status: .complete,
            assignments: [TaskAssignment(period: .day, date: resolvedDay, status: .complete)]
        )

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: [inboxTask, completedTask])
        )

        #expect(manager.overdueTaskCount == 1)
        #expect(manager.overdueTaskItems.first?.task.id == inboxTask.id)
        #expect(manager.overdueTaskItems.first?.sourceKey.kind == .inbox)
    }
}
