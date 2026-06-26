import Foundation
import Testing
@testable import Spread

/// Tests for `NoteCoordinator`, constructed directly with a `TestNoteRepository` and a
/// `JournalRuleEngine` — no `JournalManager` involved. Mirrors the scenarios already
/// exercised through `JournalManager`'s existing black-box test suites
/// (`JournalManagerNoteTests`, `MigrationTests`), since no legacy `Standard*` coordinator
/// exists anymore to parity-test against.
@MainActor
struct NoteCoordinatorTests {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeCoordinator() -> (coordinator: NoteCoordinator, repository: TestNoteRepository) {
        let repository = TestNoteRepository()
        let ruleEngine = JournalRuleEngine(calendar: Self.calendar)
        return (NoteCoordinator(noteRepository: repository, ruleEngine: ruleEngine), repository)
    }

    // MARK: - Creation

    /// Setup: a day spread exists and matches the new note's preferred date/period.
    /// Expected: the created note has a current assignment matching that spread.
    @Test func testAddNoteReconcilesAgainstMatchingSpread() async throws {
        let (coordinator, repository) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)

        let note = try await coordinator.addNote(title: "New Note", date: date, period: .day, spreads: [daySpread])

        #expect(note.title == "New Note")
        #expect(note.currentAssignments.count == 1)
        #expect(note.currentAssignments[0].status == .active)
        #expect(await repository.getNotes().map(\.id) == [note.id])
    }

    /// Setup: no spreads exist that match the new note's preferred date.
    /// Expected: the note is created with no current assignment (Inbox).
    @Test func testAddNoteWithNoMatchingSpreadLeavesNoteUnassigned() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!

        let note = try await coordinator.addNote(title: "Inbox Note", date: date, period: .day, spreads: [])

        #expect(note.currentAssignments.isEmpty)
    }

    // MARK: - Updates

    /// Setup: an existing note.
    /// Expected: `updateTitle` changes title and content and persists them.
    @Test func testUpdateTitlePersistsChange() async throws {
        let (coordinator, repository) = makeCoordinator()
        let note = DataModel.Note(title: "Original", content: "Old content")
        try await repository.save(note, change: EntityChange())

        try await coordinator.updateTitle(note, newTitle: "Updated", newContent: "New content")

        #expect(note.title == "Updated")
        #expect(note.content == "New content")
        let saved = await repository.getNotes().first
        #expect(saved?.title == "Updated")
    }

    /// Setup: an existing note.
    /// Expected: `updateMetadata` updates list/tags and stamps the list LWW timestamp only
    /// when the list actually changed.
    @Test func testUpdateMetadataUpdatesChangedFieldsOnly() async throws {
        let (coordinator, _) = makeCoordinator()
        let note = DataModel.Note(title: "Note")
        let list = DataModel.List(name: "Personal")
        let tag = DataModel.Tag(name: "Ideas")

        try await coordinator.updateMetadata(note, list: list, tags: [tag])

        #expect(note.list?.id == list.id)
        #expect(note.tags.map(\.id) == [tag.id])
        #expect(note.listUpdatedAt != nil)
    }

    /// Setup: a note with no preferred assignment; a day spread matching the new date exists.
    /// Expected: `updateDateAndPeriod` sets the new date/period and reconciles a current
    /// assignment against the matching spread.
    @Test func testUpdateDateAndPeriodReconcilesAssignment() async throws {
        let (coordinator, _) = makeCoordinator()
        let note = DataModel.Note(title: "Note", date: nil)
        let newDate = Self.calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let daySpread = DataModel.Spread(period: .day, date: newDate, calendar: Self.calendar)

        try await coordinator.updateDateAndPeriod(note, newDate: newDate, newPeriod: .day, spreads: [daySpread])

        #expect(note.period == .day)
        #expect(note.currentAssignments.count == 1)
    }

    // MARK: - Deletion

    /// Setup: an existing note in the repository.
    /// Expected: `delete` removes it from the repository.
    @Test func testDeleteRemovesFromRepository() async throws {
        let (coordinator, repository) = makeCoordinator()
        let note = DataModel.Note(title: "Note")
        try await repository.save(note, change: EntityChange())

        try await coordinator.delete(note)

        let remaining = await repository.getNotes()
        #expect(remaining.isEmpty)
    }

    // MARK: - Migration

    /// Setup: a note with no assignment on the claimed source spread.
    /// Expected: `migrateNote` throws `MigrationError.noSourceAssignment`.
    @Test func testMigrateNoteRejectsMissingSourceAssignment() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let note = DataModel.Note(title: "Note", date: date, period: .day, currentAssignments: [])

        await #expect(throws: MigrationError.noSourceAssignment) {
            try await coordinator.migrateNote(note, from: monthSpread, to: daySpread)
        }
    }

    /// Setup: a note currently assigned to a month spread.
    /// Expected: `migrateNote` moves the month assignment to history and creates a new
    /// `.active` assignment for the day destination.
    @Test func testMigrateNoteMovesAssignmentToDestination() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Note", date: date, period: .month,
            currentAssignments: [Assignment(period: .month, date: date, status: .active)]
        )

        try await coordinator.migrateNote(note, from: monthSpread, to: daySpread)

        #expect(note.migrationHistory.count == 1)
        #expect(note.currentAssignments.count == 1)
        #expect(note.currentAssignments[0].period == .day)
        #expect(note.currentAssignments[0].status == .active)
    }

    /// Setup: a note migrating to a destination spread it had previously visited and been
    /// migrated away from (a migrated-history assignment already exists there).
    /// Expected: the historical destination assignment is revived (same `id`, reactivated)
    /// rather than a new one being minted.
    @Test func testMigrateNoteRevivesHistoricalDestination() async throws {
        let (coordinator, _) = makeCoordinator()
        let date = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let historicalID = UUID()
        let note = DataModel.Note(
            title: "Note", date: date, period: .month,
            currentAssignments: [Assignment(period: .month, date: date, status: .active)],
            migrationHistory: [Assignment(id: historicalID, period: .day, date: date, status: .migrated)]
        )

        try await coordinator.migrateNote(note, from: monthSpread, to: daySpread)

        #expect(note.currentAssignments.count == 1)
        #expect(note.currentAssignments[0].id == historicalID)
        #expect(note.currentAssignments[0].status == .active)
    }
}
