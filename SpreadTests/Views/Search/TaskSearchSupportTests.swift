import Foundation
import Testing
@testable import Spread

@MainActor
struct TaskSearchSupportTests {
    /// Conditions: conventional mode with inbox, year, month, and day tasks.
    /// Expected: search sections keep Inbox first and then follow the same spread ordering as the navigator.
    @Test func testConventionalSectionsKeepInboxFirstAndNavigatorOrder() async throws {
        let calendar = Self.utcCalendar
        let yearDate = Self.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let monthDate = Self.makeDate(year: 2026, month: 4, day: 1, calendar: calendar)
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)

        let inboxTask = DataModel.Task(title: "Inbox task", date: dayDate, period: .day, status: .open)
        let yearTask = DataModel.Task(
            title: "Year task",
            date: yearDate,
            period: .year,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: yearDate, status: .open)]
        )
        let monthTask = DataModel.Task(
            title: "Month task",
            date: monthDate,
            period: .month,
            status: .open,
            assignments: [TaskAssignment(period: .month, date: monthDate, status: .open)]
        )
        let dayTask = DataModel.Task(
            title: "Day task",
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: dayDate,
            taskRepository: InMemoryTaskRepository(tasks: [inboxTask, yearTask, monthTask, dayTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread, daySpread]),
            bujoMode: .conventional
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "")

        #expect(sections.map(\.title) == ["Inbox", "2026", "April 2026", "April 6, 2026"])
    }

    /// Conditions: traditional mode with year, month, and day preferred tasks plus a cancelled task.
    /// Expected: tasks appear once under their most specific displayed section and cancelled tasks are excluded.
    @Test func testTraditionalSectionsUseMostSpecificPreferredPeriod() async throws {
        let calendar = Self.utcCalendar
        let yearDate = Self.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let monthDate = Self.makeDate(year: 2026, month: 4, day: 1, calendar: calendar)
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6, calendar: calendar)

        let yearTask = DataModel.Task(title: "Year task", date: yearDate, period: .year, status: .open)
        let monthTask = DataModel.Task(title: "Month task", date: monthDate, period: .month, status: .complete)
        let dayTask = DataModel.Task(title: "Day task", date: dayDate, period: .day, status: .open)
        let cancelledTask = DataModel.Task(title: "Cancelled task", date: dayDate, period: .day, status: .cancelled)

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: dayDate,
            taskRepository: InMemoryTaskRepository(tasks: [yearTask, monthTask, dayTask, cancelledTask]),
            spreadRepository: InMemorySpreadRepository(),
            bujoMode: .traditional
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "")

        #expect(sections.map(\.title) == ["2026", "April 2026", "April 6, 2026"])
        #expect(sections.flatMap(\.rows).map(\.title).contains("Cancelled task") == false)
    }

    /// Conditions: conventional mode with a task that has both migrated and active assignments.
    /// Expected: the task appears exactly once under the active destination spread and never under the migrated source.
    @Test func testConventionalSearchUsesCurrentDisplayedSpreadOnce() async throws {
        let calendar = Self.utcCalendar
        let yearDate = Self.makeDate(year: 2026, month: 1, day: 1, calendar: calendar)
        let monthDate = Self.makeDate(year: 2026, month: 4, day: 1, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)
        let migratedTask = DataModel.Task(
            title: "Migrated task",
            date: monthDate,
            period: .month,
            status: .open,
            assignments: [
                TaskAssignment(period: .year, date: yearDate, status: .migrated),
                TaskAssignment(period: .month, date: monthDate, status: .open)
            ]
        )

        let manager = try await JournalManager.make(
            calendar: calendar,
            today: monthDate,
            taskRepository: InMemoryTaskRepository(tasks: [migratedTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread, monthSpread]),
            bujoMode: .conventional
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "")

        #expect(sections.map(\.title) == ["April 2026"])
        #expect(sections.first?.rows.map(\.title) == ["Migrated task"])
    }

    @Test func testSearchMatchesTaskBodyAndCarriesMetadata() async throws {
        let calendar = Self.utcCalendar
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6, calendar: calendar)
        let dueDate = Self.makeDate(year: 2026, month: 4, day: 7, calendar: calendar)
        let task = DataModel.Task(
            title: "Launch",
            body: "Prepare rollout checklist",
            priority: .high,
            dueDate: dueDate,
            date: dayDate,
            period: .day,
            hasPreferredAssignment: false,
            status: .open
        )
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: dayDate,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(),
            bujoMode: .conventional
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "rollout")
        let row = try #require(sections.first?.rows.first)

        #expect(sections.map(\.title) == ["Inbox"])
        #expect(row.title == "Launch")
        #expect(row.bodyPreview == "Prepare rollout checklist")
        #expect(row.priority == .high)
        #expect(row.dueDate == dueDate)
        #expect(row.hasPreferredAssignment == false)
    }

    @Test func testTraditionalNilAssignmentTasksStayInboxFirst() async throws {
        let calendar = Self.utcCalendar
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6, calendar: calendar)
        let unassignedTask = DataModel.Task(
            title: "Unassigned",
            date: dayDate,
            period: .day,
            hasPreferredAssignment: false,
            status: .open
        )
        let assignedTask = DataModel.Task(
            title: "Assigned",
            date: dayDate,
            period: .day,
            status: .open
        )
        let manager = try await JournalManager.make(
            calendar: calendar,
            today: dayDate,
            taskRepository: InMemoryTaskRepository(tasks: [assignedTask, unassignedTask]),
            spreadRepository: InMemorySpreadRepository(),
            bujoMode: .traditional
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "")

        #expect(sections.map(\.title) == ["Inbox", "April 6, 2026"])
        #expect(sections.first?.rows.map(\.title) == ["Unassigned"])
        #expect(sections.first?.rows.first?.selection == nil)
        #expect(sections.first?.rows.first?.hasPreferredAssignment == false)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
