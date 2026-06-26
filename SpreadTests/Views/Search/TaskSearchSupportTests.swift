import Foundation
import Testing
@testable import Spread

@MainActor
struct TaskSearchSupportTests {
    /// Conditions: inbox, year, month, and day tasks.
    /// Expected: search sections keep Inbox first and then follow the same spread ordering as the navigator.
    @Test func testSectionsKeepInboxFirstAndNavigatorOrder() async throws {
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
            assignments: [Assignment(period: .year, date: yearDate, status: .open)]
        )
        let monthTask = DataModel.Task(
            title: "Month task",
            date: monthDate,
            period: .month,
            status: .open,
            assignments: [Assignment(period: .month, date: monthDate, status: .open)]
        )
        let dayTask = DataModel.Task(
            title: "Day task",
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )

        let manager = try await JournalManager(
            calendar: calendar,
            today: dayDate,
            taskRepository: TestTaskRepository(tasks: [inboxTask, yearTask, monthTask, dayTask]),
            spreadRepository: TestSpreadRepository(spreads: [yearSpread, monthSpread, daySpread])
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "")

        #expect(sections.map(\.title) == ["Inbox", "2026", "April 2026", "April 6, 2026"])
    }

    /// Conditions: a task that has both migrated and active assignments.
    /// Expected: the task appears exactly once under the active destination spread and never under the migrated source.
    @Test func testSearchUsesCurrentDisplayedSpreadOnce() async throws {
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
                Assignment(period: .year, date: yearDate, status: .migrated),
                Assignment(period: .month, date: monthDate, status: .open)
            ]
        )

        let manager = try await JournalManager(
            calendar: calendar,
            today: monthDate,
            taskRepository: TestTaskRepository(tasks: [migratedTask]),
            spreadRepository: TestSpreadRepository(spreads: [yearSpread, monthSpread])
        )

        let sections = TaskSearchSectionBuilder(journalManager: manager).build(searchText: "")

        #expect(sections.map(\.title) == ["April 2026"])
        #expect(sections.first?.rows.map(\.title) == ["Migrated task"])
    }

    /// Conditions: a task with body text, priority, and due date.
    /// Expected: search matches body text and the row carries full metadata.
    @Test func testSearchMatchesTaskBodyAndCarriesMetadata() async throws {
        let calendar = Self.utcCalendar
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6, calendar: calendar)
        let dueDate = Self.makeDate(year: 2026, month: 4, day: 7, calendar: calendar)
        let task = DataModel.Task(
            title: "Launch",
            body: "Prepare rollout checklist",
            priority: .high,
            dueDate: dueDate,
            date: nil,
            period: nil,
            status: .open
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: dayDate,
            taskRepository: TestTaskRepository(tasks: [task]),
            spreadRepository: TestSpreadRepository()
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

    /// Conditions: a task without a preferred assignment (inbox) alongside one with an explicit day assignment.
    /// Expected: unassigned task appears in Inbox, assigned task in its spread section.
    @Test func testNilAssignmentTasksStayInboxFirst() async throws {
        let calendar = Self.utcCalendar
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 6, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)
        let unassignedTask = DataModel.Task(
            title: "Unassigned",
            date: nil,
            period: nil,
            status: .open
        )
        let assignedTask = DataModel.Task(
            title: "Assigned",
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let manager = try await JournalManager(
            calendar: calendar,
            today: dayDate,
            taskRepository: TestTaskRepository(tasks: [assignedTask, unassignedTask]),
            spreadRepository: TestSpreadRepository(spreads: [daySpread])
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
