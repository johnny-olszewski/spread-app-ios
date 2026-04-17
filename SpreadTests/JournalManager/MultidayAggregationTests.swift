import Foundation
import Testing
@testable import Spread

/// Tests for multiday spread aggregation across date boundaries.
///
/// Verifies that multiday spreads correctly aggregate entries whose preferred
/// dates fall within the range, including ranges that cross month and year boundaries.
@Suite("Multiday Aggregation Tests")
@MainActor
struct MultidayAggregationTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeManager(
        tasks: [DataModel.Task] = [],
        notes: [DataModel.Note] = [],
        spreads: [DataModel.Spread] = []
    ) async throws -> JournalManager {
        try await JournalManager.make(
            calendar: Self.testCalendar,
            taskRepository: InMemoryTaskRepository(tasks: tasks),
            spreadRepository: InMemorySpreadRepository(spreads: spreads),
            noteRepository: InMemoryNoteRepository(notes: notes)
        )
    }

    // MARK: - Month Boundary Tests

    /// Condition: Multiday range spans from January 28 to February 3.
    /// Expected: Tasks from both January and February within the range are included.
    @Test("Multiday aggregation across month boundary includes entries from both months")
    func testAggregationAcrossMonthBoundary() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 28))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 3))!

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let janTask = DataModel.Task(
            title: "Jan 30 task",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 30))!,
            period: .day
        )
        let febTask = DataModel.Task(
            title: "Feb 2 task",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 2))!,
            period: .day
        )
        let outsideTask = DataModel.Task(
            title: "Feb 5 task",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!,
            period: .day
        )

        let manager = try await makeManager(
            tasks: [janTask, febTask, outsideTask],
            spreads: [spread]
        )

        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.count == 2)
        let taskIds = Set(data?.tasks.map(\.id) ?? [])
        #expect(taskIds.contains(janTask.id))
        #expect(taskIds.contains(febTask.id))
        #expect(!taskIds.contains(outsideTask.id))
    }

    // MARK: - Year Boundary Tests

    /// Condition: Multiday range spans from December 29 to January 4 across year boundary.
    /// Expected: Entries from both years within the range are included.
    @Test("Multiday aggregation across year boundary includes entries from both years")
    func testAggregationAcrossYearBoundary() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: DateComponents(year: 2025, month: 12, day: 29))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let dec31Task = DataModel.Task(
            title: "Dec 31 task",
            date: calendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!,
            period: .day
        )
        let jan2Task = DataModel.Task(
            title: "Jan 2 task",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            period: .day
        )
        let jan2Note = DataModel.Note(
            title: "Jan 2 note",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!,
            period: .day
        )
        let outsideNote = DataModel.Note(
            title: "Jan 10 note",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!,
            period: .day
        )

        let manager = try await makeManager(
            tasks: [dec31Task, jan2Task],
            notes: [jan2Note, outsideNote],
            spreads: [spread]
        )

        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.count == 2)
        #expect(data?.notes.count == 1)
        #expect(data?.notes.first?.id == jan2Note.id)
    }

    // MARK: - Boundary Inclusivity Tests

    /// Condition: Tasks exist exactly on start and end dates.
    /// Expected: Both boundary tasks are included (inclusive range).
    @Test("Multiday range is inclusive on both start and end dates")
    func testRangeInclusivity() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let startTask = DataModel.Task(
            title: "Start boundary",
            date: startDate,
            period: .day
        )
        let endTask = DataModel.Task(
            title: "End boundary",
            date: endDate,
            period: .day
        )
        let beforeTask = DataModel.Task(
            title: "Before range",
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!,
            period: .day
        )
        let afterTask = DataModel.Task(
            title: "After range",
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!,
            period: .day
        )

        let manager = try await makeManager(
            tasks: [startTask, endTask, beforeTask, afterTask],
            spreads: [spread]
        )

        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.count == 2)
        let taskIds = Set(data?.tasks.map(\.id) ?? [])
        #expect(taskIds.contains(startTask.id))
        #expect(taskIds.contains(endTask.id))
    }

    // MARK: - Mixed Entry Types

    /// Condition: Both tasks and notes within the multiday range.
    /// Expected: Both types are aggregated into the spread data model.
    @Test("Multiday aggregation includes both tasks and notes")
    func testMixedEntryTypes() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 7))!

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let task = DataModel.Task(
            title: "Task in range",
            date: calendar.date(from: DateComponents(year: 2026, month: 5, day: 3))!,
            period: .day
        )
        let note = DataModel.Note(
            title: "Note in range",
            date: calendar.date(from: DateComponents(year: 2026, month: 5, day: 5))!,
            period: .day
        )

        let manager = try await makeManager(
            tasks: [task],
            notes: [note],
            spreads: [spread]
        )

        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.count == 1)
        #expect(data?.notes.count == 1)
        #expect(data?.tasks.first?.id == task.id)
        #expect(data?.notes.first?.id == note.id)
    }

    // MARK: - Cancelled Task Exclusion

    /// Condition: Cancelled task has a date within the multiday range.
    /// Expected: Cancelled tasks are excluded from multiday aggregation.
    @Test("Cancelled tasks are excluded from multiday aggregation")
    func testCancelledTasksExcluded() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7))!

        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        let activeTask = DataModel.Task(
            title: "Active task",
            date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 3))!,
            period: .day,
            status: .open
        )
        let cancelledTask = DataModel.Task(
            title: "Cancelled task",
            date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))!,
            period: .day,
            status: .cancelled
        )

        let manager = try await makeManager(
            tasks: [activeTask, cancelledTask],
            spreads: [spread]
        )

        let data = manager.dataModel[.multiday]?[spread.date]

        #expect(data?.tasks.count == 2)
        #expect(data?.tasks.map(\.id) == [activeTask.id, cancelledTask.id])
    }
}
