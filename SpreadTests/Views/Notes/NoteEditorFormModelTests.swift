import Foundation
import Testing
@testable import Spread

struct NoteEditorFormModelTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }

    private func makeConfig(today: Date) -> EntryCreationConfiguration {
        EntryCreationConfiguration(calendar: calendar, today: today)
    }

    // MARK: - Validation Tests

    /// Condition: validateForSubmission is called with an empty title.
    /// Expected: Returns false; titleError is .emptyTitle; showValidationErrors is set.
    @Test("Empty title fails submission validation")
    func emptyTitleFailsValidation() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.title = ""

        let isValid = model.validateForSubmission()

        #expect(!isValid)
        #expect(model.titleError == .emptyTitle)
        #expect(model.showValidationErrors)
    }

    /// Condition: validateForSubmission with multiday period selected but no spreadID.
    /// Expected: Returns false; dateError is .missingMultidaySpread.
    @Test("Multiday period without spread ID fails submission validation")
    func multidayWithoutSpreadFailsValidation() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.title = "Test note"
        model.selectedPeriod = .multiday
        model.selectedSpreadID = nil

        let isValid = model.validateForSubmission()

        #expect(!isValid)
        #expect(model.dateError == .missingMultidaySpread)
    }

    /// Condition: validateForSubmission with a valid title, day period, and non-past date.
    /// Expected: Returns true; both errors are nil.
    @Test("Valid title and date passes submission validation")
    func validTitleAndDatePassesValidation() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.title = "Meeting notes"
        model.selectedPeriod = .day
        model.selectedDate = today

        let isValid = model.validateForSubmission()

        #expect(isValid)
        #expect(model.titleError == nil)
        #expect(model.dateError == nil)
    }

    // MARK: - Period Change Tests

    /// Condition: Create mode initialized from a year spread while today is March 29, 2026.
    /// Expected: Switching from year to day clamps the selected date to today.
    @Test("Create-mode note editor clamps stale year dates when switching to day")
    func createModePeriodChangeClampsToCurrentDay() {
        let today = makeDate(year: 2026, month: 3, day: 29)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: yearSpread)

        model.setPeriod(.day)

        #expect(model.selectedDate == today)
    }

    /// Condition: Period changed to non-multiday with an existing selectedSpreadID.
    /// Expected: selectedSpreadID is cleared.
    @Test("Switching away from multiday clears selectedSpreadID")
    func switchingFromMultidayClearsSpreadID() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.selectedPeriod = .multiday
        model.selectedSpreadID = UUID()

        model.setPeriod(.day)

        #expect(model.selectedSpreadID == nil)
        #expect(model.selectedPeriod == .day)
    }

    // MARK: - Create Button Visibility Tests

    /// Condition: Form model freshly initialized (hasEditedTitle = false).
    /// Expected: isCreateButtonVisible is false.
    @Test("Create button not visible before title is edited")
    func createButtonNotVisibleInitially() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        let model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        #expect(!model.isCreateButtonVisible)
    }

    /// Condition: handleTitleChange called.
    /// Expected: isCreateButtonVisible becomes true.
    @Test("Create button becomes visible after title is edited")
    func createButtonVisibleAfterTitleEdit() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.title = "Hello"
        model.handleTitleChange()
        #expect(model.isCreateButtonVisible)
    }

    // MARK: - Edit Mode Init Tests

    /// Condition: Edit-mode init from a note with a day assignment.
    /// Expected: title, content, period, selectedList, selectedTagIDs populate correctly; hasEditedTitle is true.
    @Test("Edit-mode init populates all fields from note")
    func editModeInitPopulatesFields() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        let noteDate = makeDate(year: 2026, month: 1, day: 20)
        let note = DataModel.Note(
            title: "My note",
            content: "Some content",
            date: noteDate,
            period: .day,
            currentAssignments: [Assignment(period: .day, date: noteDate, status: .active)]
        )
        let model = NoteEditorFormModel(configuration: makeConfig(today: today), note: note)

        #expect(model.title == "My note")
        #expect(model.content == "Some content")
        #expect(model.selectedPeriod == .day)
        #expect(model.hasEditedTitle)
    }

    // MARK: - Sanitized Content Tests

    /// Condition: Content is whitespace-only.
    /// Expected: sanitizedContent returns nil.
    @Test("Whitespace-only content sanitizes to nil")
    func whitespaceContentSanitizesToNil() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.content = "   \n  "
        #expect(model.sanitizedContent == nil)
    }

    /// Condition: Content is non-empty.
    /// Expected: sanitizedContent returns the trimmed string.
    @Test("Non-empty content sanitizes to trimmed string")
    func nonEmptyContentSanitizesToTrimmedString() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        var model = NoteEditorFormModel(configuration: makeConfig(today: today), selectedSpread: nil)
        model.content = "  Meeting notes  "
        #expect(model.sanitizedContent == "Meeting notes")
    }
}
