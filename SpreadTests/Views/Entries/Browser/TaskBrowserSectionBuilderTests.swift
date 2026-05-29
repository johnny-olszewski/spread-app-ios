import Foundation
import Testing
@testable import Spread

/// Tests for TaskBrowserSectionBuilder ordering and filtering logic.
///
/// Verifies:
/// - Inbox tasks appear before assigned tasks in the Open section
/// - Assigned open tasks sort by date, period, then createdDate
/// - Terminal tasks sort by statusUpdatedAt descending
/// - List filter returns only matching tasks
/// - Multi-Tag OR filter returns tasks with any selected tag
/// - Combined List + Tag filter applies AND across types
/// - Search query applied on top of active filters
/// - Notes mode ordering (createdDate descending)
@Suite("TaskBrowserSectionBuilder Tests")
struct TaskBrowserSectionBuilderTests {

    // MARK: - Fixtures

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private var builder: TaskBrowserSectionBuilder {
        TaskBrowserSectionBuilder(
            calendar: calendar,
            today: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func allOpenRows(from sections: [TaskBrowserSection]) -> [TaskBrowserRow] {
        sections.filter { if case .terminal = $0.kind { return false }; return true }.flatMap(\.rows)
    }

    private func terminalRows(from sections: [TaskBrowserSection]) -> [TaskBrowserRow] {
        sections.first { if case .terminal = $0.kind { return true }; return false }?.rows ?? []
    }

    private func makeTask(
        title: String = "Task",
        status: EntryStatus = .open,
        hasPreferredAssignment: Bool = false,
        date: Date? = nil,
        period: Period = .day,
        createdDate: Date = .distantPast,
        list: DataModel.List? = nil,
        tags: [DataModel.Tag] = [],
        assignments: [TaskAssignment] = []
    ) -> DataModel.Task {
        DataModel.Task(
            title: title,
            createdDate: createdDate,
            date: date ?? makeDate(year: 2026, month: 1, day: 1),
            period: period,
            hasPreferredAssignment: hasPreferredAssignment,
            status: status,
            assignments: assignments,
            list: list,
            tags: tags
        )
    }

    // MARK: - Open Section Ordering

    /// Conditions: mix of inbox and assigned open tasks.
    /// Expected: all inbox tasks appear before all assigned tasks in the Open section.
    @Test("Inbox tasks appear before assigned tasks in Open section")
    func inboxTasksBeforeAssignedInOpenSection() {
        let assignedTask = makeTask(
            title: "Assigned",
            hasPreferredAssignment: true,
            date: makeDate(year: 2026, month: 1, day: 5),
            createdDate: makeDate(year: 2026, month: 1, day: 1)
        )
        let inboxTask = makeTask(
            title: "Inbox",
            hasPreferredAssignment: false,
            createdDate: makeDate(year: 2026, month: 1, day: 10)
        )

        let sections = builder.build(
            tasks: [assignedTask, inboxTask],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows.count == 2)
        #expect(openRows[0].task.title == "Inbox")
        #expect(openRows[1].task.title == "Assigned")
    }

    /// Conditions: two inbox tasks with different createdDates.
    /// Expected: inbox tasks ordered by createdDate ascending.
    @Test("Inbox tasks ordered by createdDate ascending")
    func inboxTasksOrderedByCreatedDateAscending() {
        let older = makeTask(title: "Older", createdDate: makeDate(year: 2026, month: 1, day: 1))
        let newer = makeTask(title: "Newer", createdDate: makeDate(year: 2026, month: 1, day: 5))

        let sections = builder.build(
            tasks: [newer, older],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows[0].task.title == "Older")
        #expect(openRows[1].task.title == "Newer")
    }

    /// Conditions: assigned tasks on same date with different periods (day vs month).
    /// Expected: day-period task sorts before month-period task.
    @Test("Day-period task sorts before month-period task for same date")
    func dayPeriodSortsBeforeMonthPeriod() {
        let jan = makeDate(year: 2026, month: 1, day: 1)
        let dayTask = makeTask(
            title: "Day",
            hasPreferredAssignment: true,
            date: jan,
            period: .day,
            createdDate: makeDate(year: 2026, month: 1, day: 10)
        )
        let monthTask = makeTask(
            title: "Month",
            hasPreferredAssignment: true,
            date: jan,
            period: .month,
            createdDate: makeDate(year: 2026, month: 1, day: 1)
        )

        let sections = builder.build(
            tasks: [monthTask, dayTask],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows[0].task.title == "Day")
        #expect(openRows[1].task.title == "Month")
    }

    /// Conditions: assigned open tasks on different normalized dates.
    /// Expected: earlier-date task appears first.
    @Test("Assigned open tasks ordered by normalized date ascending")
    func assignedOpenTasksOrderedByDateAscending() {
        let earlyTask = makeTask(
            title: "Early",
            hasPreferredAssignment: true,
            date: makeDate(year: 2026, month: 1, day: 5)
        )
        let lateTask = makeTask(
            title: "Late",
            hasPreferredAssignment: true,
            date: makeDate(year: 2026, month: 3, day: 1)
        )

        let sections = builder.build(
            tasks: [lateTask, earlyTask],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows[0].task.title == "Early")
        #expect(openRows[1].task.title == "Late")
    }

    // MARK: - Terminal Section Ordering

    /// Conditions: two complete tasks with different statusUpdatedAt dates.
    /// Expected: more recently completed task appears first (desc order).
    @Test("Completed tasks ordered by statusUpdatedAt descending")
    func completedTasksOrderedByStatusUpdatedAtDescending() {
        let earlierDate = makeDate(year: 2026, month: 1, day: 5)
        let laterDate = makeDate(year: 2026, month: 1, day: 10)

        let olderTask = makeTask(
            title: "OlderCompletion",
            status: .complete,
            assignments: [
                TaskAssignment(
                    id: UUID(),
                    period: .day,
                    date: makeDate(year: 2026, month: 1, day: 1),
                    status: .complete,
                    statusUpdatedAt: earlierDate
                )
            ]
        )
        let newerTask = makeTask(
            title: "NewerCompletion",
            status: .complete,
            assignments: [
                TaskAssignment(
                    id: UUID(),
                    period: .day,
                    date: makeDate(year: 2026, month: 1, day: 1),
                    status: .complete,
                    statusUpdatedAt: laterDate
                )
            ]
        )

        let sections = builder.build(
            tasks: [olderTask, newerTask],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let terminalRows = terminalRows(from: sections)

        #expect(terminalRows.count == 2)
        #expect(terminalRows[0].task.title == "NewerCompletion")
        #expect(terminalRows[1].task.title == "OlderCompletion")
    }

    /// Conditions: terminal task with nil statusUpdatedAt falls back to createdDate.
    /// Expected: task with statusUpdatedAt sorts above task with nil statusUpdatedAt.
    @Test("Terminal task with statusUpdatedAt sorts above task without")
    func terminalTaskWithStatusDateSortsAboveNil() {
        let withDate = makeTask(
            title: "WithDate",
            status: .complete,
            createdDate: makeDate(year: 2026, month: 1, day: 1),
            assignments: [
                TaskAssignment(
                    id: UUID(),
                    period: .day,
                    date: makeDate(year: 2026, month: 1, day: 1),
                    status: .complete,
                    statusUpdatedAt: makeDate(year: 2026, month: 1, day: 5)
                )
            ]
        )
        let withoutDate = makeTask(
            title: "WithoutDate",
            status: .complete,
            createdDate: makeDate(year: 2026, month: 1, day: 10)
        )

        let sections = builder.build(
            tasks: [withoutDate, withDate],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let terminalRows = terminalRows(from: sections)

        #expect(terminalRows[0].task.title == "WithDate")
        #expect(terminalRows[1].task.title == "WithoutDate")
    }

    // MARK: - List Filter

    /// Conditions: tasks belonging to different lists; one list filter active.
    /// Expected: only tasks in the selected list are returned.
    @Test("List filter returns only tasks belonging to selected list")
    func listFilterReturnsOnlyMatchingTasks() {
        let workList = DataModel.List(name: "Work")
        let homeList = DataModel.List(name: "Home")

        let workTask = makeTask(title: "Work Task", list: workList)
        let homeTask = makeTask(title: "Home Task", list: homeList)
        let unlistedTask = makeTask(title: "Unlisted Task")

        let sections = builder.build(
            tasks: [workTask, homeTask, unlistedTask],
            selectedList: workList,
            selectedTagIDs: [],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows.count == 1)
        #expect(openRows[0].task.title == "Work Task")
    }

    // MARK: - Tag Filter

    /// Conditions: tasks with different tags; two tags selected.
    /// Expected: tasks with any of the selected tags are included (OR).
    @Test("Multi-tag OR filter returns tasks with any selected tag")
    func multiTagORFilterReturnsTasksWithAnySelectedTag() {
        let tagA = DataModel.Tag(name: "Alpha")
        let tagB = DataModel.Tag(name: "Beta")
        let tagC = DataModel.Tag(name: "Gamma")

        let taskAB = makeTask(title: "AB Task", tags: [tagA, tagB])
        let taskB = makeTask(title: "B Task", tags: [tagB])
        let taskC = makeTask(title: "C Task", tags: [tagC])
        let untagged = makeTask(title: "Untagged")

        let sections = builder.build(
            tasks: [taskAB, taskB, taskC, untagged],
            selectedList: nil,
            selectedTagIDs: [tagA.id, tagB.id],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)
        let titles = openRows.map { $0.task.title }

        #expect(titles.contains("AB Task"))
        #expect(titles.contains("B Task"))
        #expect(!titles.contains("C Task"))
        #expect(!titles.contains("Untagged"))
    }

    // MARK: - Combined Filter

    /// Conditions: list filter and tag filter both active.
    /// Expected: only tasks matching the list AND having at least one selected tag are returned.
    @Test("Combined list and tag filter applies AND across types")
    func combinedListAndTagFilterAppliesAND() {
        let workList = DataModel.List(name: "Work")
        let tagA = DataModel.Tag(name: "Alpha")

        let workTagged = makeTask(title: "Work+Tagged", list: workList, tags: [tagA])
        let workOnly = makeTask(title: "Work only", list: workList)
        let taggedOnly = makeTask(title: "Tagged only", tags: [tagA])

        let sections = builder.build(
            tasks: [workTagged, workOnly, taggedOnly],
            selectedList: workList,
            selectedTagIDs: [tagA.id],
            searchText: ""
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows.count == 1)
        #expect(openRows[0].task.title == "Work+Tagged")
    }

    // MARK: - Search Filter

    /// Conditions: search query active alongside list filter.
    /// Expected: search filters within the already-list-filtered results.
    @Test("Search query applied on top of active list filter")
    func searchQueryAppliedOnTopOfListFilter() {
        let workList = DataModel.List(name: "Work")
        let taskA = makeTask(title: "Deploy server", list: workList)
        let taskB = makeTask(title: "Write docs", list: workList)
        let homeTask = makeTask(title: "Deploy garden", list: nil)

        let sections = builder.build(
            tasks: [taskA, taskB, homeTask],
            selectedList: workList,
            selectedTagIDs: [],
            searchText: "Deploy"
        )
        let openRows = allOpenRows(from: sections)

        #expect(openRows.count == 1)
        #expect(openRows[0].task.title == "Deploy server")
    }

    // MARK: - Migrated Tasks Excluded

    /// Conditions: mix of open, complete, cancelled, and migrated tasks.
    /// Expected: migrated tasks do not appear in either section.
    @Test("Migrated tasks are excluded from all sections")
    func migratedTasksExcludedFromAllSections() {
        let openTask = makeTask(title: "Open", status: .open)
        let completeTask = makeTask(title: "Complete", status: .complete)
        let migratedTask = makeTask(title: "Migrated", status: .migrated)

        let sections = builder.build(
            tasks: [openTask, completeTask, migratedTask],
            selectedList: nil,
            selectedTagIDs: [],
            searchText: ""
        )
        let allTitles = sections.flatMap { $0.rows.map { $0.task.title } }

        #expect(allTitles.contains("Open"))
        #expect(allTitles.contains("Complete"))
        #expect(!allTitles.contains("Migrated"))
    }
}
