import Foundation
import Testing
@testable import Spread

/// Tests verifying that notes are excluded from batch migration suggestions.
///
/// Notes migrate only explicitly (via swipe action or edit view).
/// They must never appear in migration banners or batch migration operations.
@Suite("Note Migration Exclusion Tests")
@MainActor
struct NoteMigrationExclusionTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        TestDataBuilders.testDate
    }

    private func makeManager(
        tasks: [DataModel.Task] = [],
        notes: [DataModel.Note] = [],
        spreads: [DataModel.Spread] = []
    ) async throws -> JournalManager {
        let calendar = Self.testCalendar
        let today = Self.testDate

        var allSpreads = spreads
        if allSpreads.isEmpty {
            allSpreads = [
                DataModel.Spread(period: .year, date: today, calendar: calendar),
                DataModel.Spread(period: .month, date: today, calendar: calendar),
                DataModel.Spread(period: .day, date: today, calendar: calendar)
            ]
        }

        return try await JournalManager.make(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: tasks),
            spreadRepository: InMemorySpreadRepository(spreads: allSpreads),
            noteRepository: InMemoryNoteRepository(notes: notes)
        )
    }

    // MARK: - eligibleTasksForMigration Excludes Notes

    /// Condition: Both tasks and notes exist on a parent spread.
    /// Expected: eligibleTasksForMigration returns only tasks, not notes.
    @Test("eligibleTasksForMigration excludes notes entirely")
    func testEligibleTasksExcludesNotes() async throws {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let monthDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)

        let task = DataModel.Task(title: "Task on year", date: yearDate, period: .year, status: .open)
        task.assignments = [
            TaskAssignment(period: .year, date: yearDate, status: .open)
        ]

        let note = DataModel.Note(title: "Note on year", date: yearDate, period: .year, status: .active)
        note.assignments = [
            NoteAssignment(period: .year, date: yearDate, status: .active)
        ]

        let manager = try await makeManager(
            tasks: [task],
            notes: [note],
            spreads: [yearSpread, monthSpread]
        )

        let eligible = manager.eligibleTasksForMigration(from: yearSpread, to: monthSpread)

        // Only the task should appear, not the note
        #expect(eligible.count == 1)
        #expect(eligible.first?.id == task.id)
    }

    /// Condition: Only notes exist on a parent spread (no tasks).
    /// Expected: eligibleTasksForMigration returns an empty array.
    @Test("eligibleTasksForMigration returns empty when only notes exist")
    func testEligibleTasksEmptyWithOnlyNotes() async throws {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let monthDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)

        let note = DataModel.Note(title: "Note on year", date: yearDate, period: .year, status: .active)
        note.assignments = [
            NoteAssignment(period: .year, date: yearDate, status: .active)
        ]

        let manager = try await makeManager(
            notes: [note],
            spreads: [yearSpread, monthSpread]
        )

        let eligible = manager.eligibleTasksForMigration(from: yearSpread, to: monthSpread)

        #expect(eligible.isEmpty)
    }

    // MARK: - Note Swipe Action Availability

    /// Condition: Active note on a spread.
    /// Expected: canMigrate is true (explicit migration via swipe is allowed).
    @Test("Active notes can migrate via explicit swipe action")
    func testActiveNoteCanMigrateExplicitly() {
        let config = EntryRowConfiguration(
            entryType: .note,
            noteStatus: .active,
            title: "Test note"
        )

        #expect(config.canMigrate == true)
    }

    /// Condition: Migrated note on a spread.
    /// Expected: canMigrate is false (already migrated).
    @Test("Migrated notes cannot migrate again")
    func testMigratedNoteCannotMigrate() {
        let config = EntryRowConfiguration(
            entryType: .note,
            noteStatus: .migrated,
            title: "Test note"
        )

        #expect(config.canMigrate == false)
    }
}
