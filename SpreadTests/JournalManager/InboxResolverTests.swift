import Foundation
import Testing
@testable import Spread

struct InboxResolverTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Setup: a task with no assignments, a cancelled task with no assignments, and an unassigned note.
    /// Expected: the resolver returns only the open task and note because cancelled tasks never belong in Inbox.
    @Test func testResolverExcludesCancelledTasksButIncludesOtherUnassignedEntries() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let openTask = DataModel.Task(title: "Open", date: dayDate, period: .day, assignments: [])
        let cancelledTask = DataModel.Task(title: "Cancelled", date: dayDate, period: .day, status: .cancelled, assignments: [])
        let note = DataModel.Note(title: "Note", date: dayDate, period: .day, assignments: [])

        let resolver = StandardInboxResolver(calendar: Self.calendar)
        let entries = resolver.inboxEntries(tasks: [openTask, cancelledTask], notes: [note], spreads: [])

        #expect(entries.map(\.id) == [openTask.id, note.id])
    }

    /// Setup: a task has only a migrated assignment that matches an existing spread.
    /// Expected: the resolver keeps it in Inbox because migrated-only history is not an active matching assignment.
    @Test func testResolverTreatsMigratedOnlyAssignmentsAsInboxEligible() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Migrated only",
            date: dayDate,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .migrated)]
        )

        let resolver = StandardInboxResolver(calendar: Self.calendar)
        let entries = resolver.inboxEntries(tasks: [task], notes: [], spreads: [spread])

        #expect(entries.map(\.id) == [task.id])
    }

    /// Setup: one task and one note have active assignments matching existing spreads.
    /// Expected: neither entry is returned in Inbox.
    @Test func testResolverExcludesEntriesWithMatchingActiveAssignments() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Assigned task",
            date: dayDate,
            period: .day,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )
        let note = DataModel.Note(
            title: "Assigned note",
            date: dayDate,
            period: .day,
            assignments: [NoteAssignment(period: .day, date: dayDate, status: .active)]
        )

        let resolver = StandardInboxResolver(calendar: Self.calendar)
        let entries = resolver.inboxEntries(tasks: [task], notes: [note], spreads: [daySpread])

        #expect(entries.isEmpty)
    }
}
