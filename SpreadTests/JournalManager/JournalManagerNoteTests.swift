import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager note CRUD operations.
@Suite("JournalManager Note CRUD Tests")
@MainActor
struct JournalManagerNoteTests {

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
            spreadRepository: InMemorySpreadRepository(spreads: allSpreads),
            noteRepository: InMemoryNoteRepository(notes: notes)
        )
    }

    // MARK: - addNote Tests

    /// Condition: Add a note with valid title, content, date, and period.
    /// Expected: Note is created and appears in the journal manager's notes list.
    @Test("Adding a note creates it in the notes list")
    func testAddNoteCreatesNote() async throws {
        let manager = try await makeManager()
        let today = Self.testDate

        let note = try await manager.addNote(
            title: "Test note",
            content: "Extended content",
            date: today,
            period: .day
        )

        #expect(note.title == "Test note")
        #expect(note.content == "Extended content")
        #expect(note.status == .active)
        #expect(manager.notes.contains { $0.id == note.id })
    }

    /// Condition: Add a note when a matching spread exists.
    /// Expected: Note gets an assignment to the matching spread.
    @Test("Adding a note assigns it to a matching spread")
    func testAddNoteAssignsToSpread() async throws {
        let manager = try await makeManager()
        let today = Self.testDate

        let note = try await manager.addNote(
            title: "Assigned note",
            date: today,
            period: .day
        )

        #expect(!note.assignments.isEmpty)
        #expect(note.assignments.first?.status == .active)
    }

    /// Condition: Add a note when no matching spread exists.
    /// Expected: Note is created with no assignments (goes to inbox).
    @Test("Adding a note without matching spread goes to inbox")
    func testAddNoteWithoutSpreadGoesToInbox() async throws {
        let calendar = Self.testCalendar
        // Create a spread for a different year so no spread matches the note's date
        let differentYear = calendar.date(byAdding: .year, value: -2, to: Self.testDate)!
        let manager = try await makeManager(spreads: [
            DataModel.Spread(period: .year, date: differentYear, calendar: calendar)
        ])

        let note = try await manager.addNote(
            title: "Inbox note",
            date: Self.testDate,
            period: .day
        )

        #expect(note.assignments.isEmpty)
    }

    /// Condition: Add a note with empty content.
    /// Expected: Note is created with empty content string.
    @Test("Adding a note with empty content succeeds")
    func testAddNoteWithEmptyContent() async throws {
        let manager = try await makeManager()

        let note = try await manager.addNote(
            title: "No content note",
            date: Self.testDate,
            period: .day
        )

        #expect(note.content == "")
    }

    // MARK: - deleteNote Tests

    /// Condition: Delete an existing note.
    /// Expected: Note is removed from the notes list.
    @Test("Deleting a note removes it from the list")
    func testDeleteNoteRemovesFromList() async throws {
        let existingNote = DataModel.Note(
            title: "Delete me",
            date: Self.testDate,
            period: .day
        )
        let manager = try await makeManager(notes: [existingNote])

        #expect(manager.notes.contains { $0.id == existingNote.id })

        try await manager.deleteNote(existingNote)

        #expect(!manager.notes.contains { $0.id == existingNote.id })
    }

    /// Condition: Delete a note and check data version.
    /// Expected: Data version is incremented.
    @Test("Deleting a note increments data version")
    func testDeleteNoteIncrementsDataVersion() async throws {
        let existingNote = DataModel.Note(
            title: "Delete version test",
            date: Self.testDate,
            period: .day
        )
        let manager = try await makeManager(notes: [existingNote])
        let initialVersion = manager.dataVersion

        try await manager.deleteNote(existingNote)

        #expect(manager.dataVersion > initialVersion)
    }

    // MARK: - updateNoteTitle Tests

    /// Condition: Update a note's title and content.
    /// Expected: The note's title and content are changed.
    @Test("Updating note title and content persists changes")
    func testUpdateNoteTitleAndContent() async throws {
        let existingNote = DataModel.Note(
            title: "Original",
            content: "Original content",
            date: Self.testDate,
            period: .day
        )
        let manager = try await makeManager(notes: [existingNote])

        try await manager.updateNoteTitle(
            existingNote,
            newTitle: "Updated",
            newContent: "Updated content"
        )

        #expect(existingNote.title == "Updated")
        #expect(existingNote.content == "Updated content")
    }

    // MARK: - updateNoteDateAndPeriod Tests

    /// Condition: Update a note's date and period.
    /// Expected: The note's date and period are changed with normalized date.
    @Test("Updating note date and period normalizes date")
    func testUpdateNoteDateAndPeriod() async throws {
        let existingNote = DataModel.Note(
            title: "Date change test",
            date: Self.testDate,
            period: .day
        )
        let manager = try await makeManager(notes: [existingNote])
        let calendar = Self.testCalendar
        let newDate = calendar.date(byAdding: .month, value: 1, to: Self.testDate)!

        try await manager.updateNoteDateAndPeriod(
            existingNote,
            newDate: newDate,
            newPeriod: .month
        )

        #expect(existingNote.period == .month)
        // Date should be normalized to month start
        let normalizedDate = Period.month.normalizeDate(newDate, calendar: calendar)
        #expect(existingNote.date == normalizedDate)
    }

    // MARK: - Data Model Integration

    /// Condition: Add a note and check it appears in the data model.
    /// Expected: Note appears in the spread data model for the matching spread.
    @Test("Added note appears in spread data model")
    func testAddedNoteAppearsInDataModel() async throws {
        let manager = try await makeManager()

        let note = try await manager.addNote(
            title: "Data model note",
            date: Self.testDate,
            period: .day
        )

        // Check the note appears in the day spread's data model
        let dayDate = Period.day.normalizeDate(Self.testDate, calendar: Self.testCalendar)
        let dayDataModel = manager.dataModel[.day]?[dayDate]

        #expect(dayDataModel?.notes.contains { $0.id == note.id } == true)
    }
}
