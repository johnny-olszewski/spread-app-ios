import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager entry-reconciliation behaviour when a new explicit spread is created.
///
/// Covers the scenario where tasks/notes are auto-assigned to a multiday spread (because no
/// day spread exists) and the user later creates a day spread — entries should migrate from
/// the multiday to the more-specific day spread.
@Suite("Spread Creation Reconciliation Tests")
@MainActor
struct SpreadCreationReconciliationTests {

    // MARK: - Helpers

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private static var multidayStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 13))!
    }

    private static var multidayEnd: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 19))!
    }

    /// A day inside the multiday range.
    private static var targetDay: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Tests

    /// Conditions: A day-preferred task exists, auto-assigned to a multiday spread because no day
    /// spread existed. The user then creates an explicit day spread for the task's preferred date.
    /// Expected: After creating the day spread, the task's assignment moves from the multiday
    /// spread to the new day spread, and the day spread's data model contains the task.
    @Test("Day spread creation pulls day-preferred task from multiday to day spread")
    func testDaySpreadCreationReconcilesDayPreferredTaskFromMultiday() async throws {
        let calendar = Self.calendar
        let multidaySpread = DataModel.Spread(
            startDate: Self.multidayStart,
            endDate: Self.multidayEnd,
            calendar: calendar
        )
        let spreadRepo = TestSpreadRepository(spreads: [multidaySpread])
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.targetDay,
            spreadRepository: spreadRepo
        )

        // Task created for Jan 15 — no day spread exists, so it auto-assigns to the multiday.
        let task = try await manager.addTask(title: "Dentist", date: Self.targetDay, period: .day)

        // Confirm auto-assignment landed on the multiday spread.
        let multidayAssignment = task.allAssignmentsForTesting.first(where: { $0.status != .migrated })
        #expect(multidayAssignment?.period == .multiday)
        #expect(multidayAssignment?.spreadID == multidaySpread.id)

        // --- Now the user creates a day spread for Jan 15 ---
        _ = try await manager.createSpread(period: .day, date: Self.targetDay)

        // The task's live assignment should now point to the day spread.
        let liveAssignment = task.allAssignmentsForTesting.first(where: { $0.status != .migrated })
        #expect(liveAssignment?.period == .day, "Expected live assignment to be .day after day spread creation, got \(String(describing: liveAssignment?.period))")

        // The day spread's data model should contain the task.
        let dayDate = Period.day.normalizeDate(Self.targetDay, calendar: calendar)
        let daySpreadData = manager.dataModel[.day]?[dayDate]
        #expect(daySpreadData != nil, "Day spread data model entry should exist")
        #expect(daySpreadData?.tasks.contains(where: { $0.id == task.id }) == true,
                "Task should appear in the day spread's data model")

        // The multiday spread's data model should NOT contain the task any more.
        let multidayData = manager.dataModel[.multiday]?[multidaySpread.date]
        #expect(multidayData?.tasks.contains(where: { $0.id == task.id }) == false,
                "Task should no longer appear in the multiday spread after reconciliation")
    }

    /// Conditions: Multiple day-preferred tasks exist across several days in a multiday spread.
    /// The user creates a day spread for ONE of those days.
    /// Expected: Only tasks for that specific day migrate; tasks for other days remain on the multiday.
    @Test("Day spread creation only migrates tasks whose preferred date matches the created spread")
    func testDaySpreadCreationOnlyMigratesMatchingDayTasks() async throws {
        let calendar = Self.calendar
        let multidaySpread = DataModel.Spread(
            startDate: Self.multidayStart,
            endDate: Self.multidayEnd,
            calendar: calendar
        )
        let spreadRepo = TestSpreadRepository(spreads: [multidaySpread])
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.targetDay,
            spreadRepository: spreadRepo
        )

        // Task for Jan 15 (will migrate to new day spread)
        let jan15Task = try await manager.addTask(title: "Jan 15 task", date: Self.targetDay, period: .day)
        // Task for Jan 16 (should remain on multiday)
        let jan16 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 16))!
        let jan16Task = try await manager.addTask(title: "Jan 16 task", date: jan16, period: .day)

        // Create day spread for Jan 15 only
        _ = try await manager.createSpread(period: .day, date: Self.targetDay)

        // Jan 15 task should be on the day spread
        let dayDate = Period.day.normalizeDate(Self.targetDay, calendar: calendar)
        let dayData = manager.dataModel[.day]?[dayDate]
        #expect(dayData?.tasks.contains(where: { $0.id == jan15Task.id }) == true)

        // Jan 16 task should still be on the multiday spread
        let multidayData = manager.dataModel[.multiday]?[multidaySpread.date]
        #expect(multidayData?.tasks.contains(where: { $0.id == jan16Task.id }) == true)

        // Jan 15 task should NOT remain on the multiday spread
        #expect(multidayData?.tasks.contains(where: { $0.id == jan15Task.id }) == false,
                "Jan 15 task should have migrated off the multiday spread")
    }

    /// Conditions: A day-preferred note exists, auto-assigned to a multiday spread because no day
    /// spread existed. The user then creates an explicit day spread for the note's preferred date.
    /// Expected: After creating the day spread, the note's assignment moves from the multiday
    /// spread to the new day spread, and the day spread's data model contains the note.
    @Test("Day spread creation pulls day-preferred note from multiday to day spread")
    func testDaySpreadCreationReconcilesDayPreferredNoteFromMultiday() async throws {
        let calendar = Self.calendar
        let multidaySpread = DataModel.Spread(
            startDate: Self.multidayStart,
            endDate: Self.multidayEnd,
            calendar: calendar
        )
        let spreadRepo = TestSpreadRepository(spreads: [multidaySpread])
        let manager = try await JournalManager(
            calendar: calendar,
            today: Self.targetDay,
            spreadRepository: spreadRepo
        )

        // Note created for Jan 15 — no day spread exists, so it auto-assigns to the multiday.
        let note = try await manager.addNote(title: "Meeting notes", date: Self.targetDay, period: .day)

        let multidayAssignment = note.allAssignmentsForTesting.first(where: { $0.status != .migrated })
        #expect(multidayAssignment?.period == .multiday)

        // --- Now the user creates a day spread for Jan 15 ---
        _ = try await manager.createSpread(period: .day, date: Self.targetDay)

        // The note's live assignment should now point to the day spread.
        let liveAssignment = note.allAssignmentsForTesting.first(where: { $0.status != .migrated })
        #expect(liveAssignment?.period == .day, "Expected live assignment to be .day after day spread creation")

        // The day spread's data model should contain the note.
        let dayDate = Period.day.normalizeDate(Self.targetDay, calendar: calendar)
        let daySpreadData = manager.dataModel[.day]?[dayDate]
        #expect(daySpreadData?.notes.contains(where: { $0.id == note.id }) == true,
                "Note should appear in the day spread's data model")
    }
}
