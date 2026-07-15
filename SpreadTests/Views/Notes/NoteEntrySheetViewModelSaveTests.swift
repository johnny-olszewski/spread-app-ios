import Foundation
import Testing
@testable import Spread

/// Tests for `NoteEntrySheet.ViewModel.saveEdits(to:journalManager:)` — the edit-mode
/// save routine's success and failure surfacing (SPRD-302).
@Suite("NoteEntrySheet ViewModel Save Tests")
@MainActor
struct NoteEntrySheetViewModelSaveTests {

    // MARK: - Test Helpers

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - Tests

    /// Tests that a failing note edit-save surfaces the error to the user.
    ///
    /// Condition: Edit a note's title, then save while the note repository throws on save.
    /// Expected: `saveEdits` returns false, `errorMessage` carries the error's description
    /// (so the sheet's error alert presents), and `isBusy` is reset so the sheet stays usable.
    @Test("Failing edit-save sets errorMessage and resets isBusy")
    func testFailingEditSaveSetsErrorMessage() async throws {
        let repository = MockNoteRepository()
        let journalManager = await JournalManager(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 7, day: 12),
            noteRepository: repository
        )
        let note = try await journalManager.addNote(
            title: "Original title",
            date: Self.makeDate(year: 2026, month: 7, day: 12),
            period: .day
        )

        repository.saveError = NSError(
            domain: "NoteEntrySheetViewModelSaveTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Disk full"]
        )

        let viewModel = NoteEntrySheet.ViewModel(note: note, journalManager: journalManager)
        viewModel.formModel.title = "Edited title"

        let success = await viewModel.saveEdits(to: note, journalManager: journalManager)

        #expect(success == false)
        #expect(viewModel.errorMessage == "Disk full")
        #expect(viewModel.isBusy == false)
    }

    /// Tests that a successful note edit-save reports success and surfaces no error.
    ///
    /// Condition: Edit a note's title, then save with a working repository.
    /// Expected: `saveEdits` returns true, `errorMessage` stays nil, and the
    /// title change is applied to the note.
    @Test("Successful edit-save returns true with no errorMessage")
    func testSuccessfulEditSaveReturnsTrue() async throws {
        let repository = MockNoteRepository()
        let journalManager = await JournalManager(
            calendar: Self.makeCalendar(),
            today: Self.makeDate(year: 2026, month: 7, day: 12),
            noteRepository: repository
        )
        let note = try await journalManager.addNote(
            title: "Original title",
            date: Self.makeDate(year: 2026, month: 7, day: 12),
            period: .day
        )

        let viewModel = NoteEntrySheet.ViewModel(note: note, journalManager: journalManager)
        viewModel.formModel.title = "Edited title"

        let success = await viewModel.saveEdits(to: note, journalManager: journalManager)

        #expect(success == true)
        #expect(viewModel.errorMessage == nil)
        #expect(note.title == "Edited title")
    }
}
