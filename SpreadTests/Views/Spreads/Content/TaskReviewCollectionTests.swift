import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct TaskReviewCollectionTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    /// Conditions: the review panel's segment order is defined by case declaration order.
    /// Expected: `allCases` is exactly Inbox, In Flight, Overdue — the spec'd segment order —
    /// and each case's section ID and empty-state message are stable.
    @Test func segmentOrderAndStaticPresentation() {
        #expect(TaskReviewCollection.allCases == [.inbox, .inFlight, .overdue])
        #expect(TaskReviewCollection.inbox.emptyStateMessage == "No inbox tasks")
        #expect(TaskReviewCollection.inFlight.emptyStateMessage == "No tasks in flight")
        #expect(TaskReviewCollection.overdue.emptyStateMessage == "Nothing overdue")
    }

    /// Conditions: a journal with one unassigned open task (inbox), one in-flight task, and
    /// one overdue open task whose day assignment matches an existing day spread (so it does
    /// not also fall into the Inbox via the unassigned fallback).
    /// Expected: each collection's `segmentTitle(in:)` shows its own live count of 1, and each
    /// collection's items contain exactly its own task — in particular the in-flight task
    /// appears nowhere but In Flight (the no-double-appearance invariant).
    @Test @MainActor func segmentTitlesCarryLiveCountsAndItemsDoNotOverlap() async throws {
        let calendar = Self.testCalendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let pastDay = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        let inboxTask = DataModel.Task(title: "Inbox task", status: .open)
        let inFlightTask = DataModel.Task(title: "In flight task", status: .inFlight)
        let overdueTask = DataModel.Task(
            title: "Overdue task",
            date: pastDay,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: pastDay, status: .open)]
        )
        let pastDaySpread = DataModel.Spread(period: .day, date: pastDay, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: TestTaskRepository(tasks: [inboxTask, inFlightTask, overdueTask]),
            spreadRepository: TestSpreadRepository(spreads: [pastDaySpread])
        )

        #expect(TaskReviewCollection.inbox.segmentTitle(in: manager) == "Inbox 1")
        #expect(TaskReviewCollection.inFlight.segmentTitle(in: manager) == "In Flight 1")
        #expect(TaskReviewCollection.overdue.segmentTitle(in: manager) == "Overdue 1")

        #expect(TaskReviewCollection.inbox.items(in: manager).map(\.task.id) == [inboxTask.id])
        #expect(TaskReviewCollection.inFlight.items(in: manager).map(\.task.id) == [inFlightTask.id])
        #expect(TaskReviewCollection.overdue.items(in: manager).map(\.task.id) == [overdueTask.id])
    }
}
