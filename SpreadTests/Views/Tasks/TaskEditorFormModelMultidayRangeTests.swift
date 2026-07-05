import Foundation
import Testing
@testable import Spread

/// SPRD-294: multiday free-range selection state on `TaskEditorFormModel`.
struct TaskEditorFormModelMultidayRangeTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }

    private func makeModel(today: Date) -> TaskEditorFormModel {
        var model = TaskEditorFormModel(
            configuration: EntryCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: nil
        )
        model.setPreferredAssignmentEnabled(true)
        model.setPeriod(.multiday)
        return model
    }

    private func makeMultidaySpread(start: Date, end: Date) -> DataModel.Spread {
        DataModel.Spread(startDate: start, endDate: end, calendar: calendar)
    }

    /// Conditions: Multiday period active, no range in progress; the user taps a date covered
    /// by an existing multiday spread.
    /// Expected: The covering spread is selected immediately — no range is started.
    @Test("Tapping a covered date selects the covering spread")
    func tapOnCoveredDateSelectsSpread() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        let spread = makeMultidaySpread(start: makeDate(year: 2026, month: 7, day: 6), end: makeDate(year: 2026, month: 7, day: 10))
        var model = makeModel(today: today)

        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 8), spreads: [spread])

        #expect(model.selectedSpreadID == spread.id)
        #expect(model.pendingRangeStart == nil)
        #expect(model.pendingMultidayRange == nil)
        #expect(model.hasMultidaySelection)
    }

    /// Conditions: Multiday period active; the user taps an uncovered date.
    /// Expected: A range starts (pendingRangeStart set); nothing is selected yet, so the
    /// multiday selection is still invalid.
    @Test("Tapping an uncovered date starts a pending range")
    func tapOnUncoveredDateStartsRange() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        var model = makeModel(today: today)

        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 6), spreads: [])

        #expect(model.pendingRangeStart == makeDate(year: 2026, month: 7, day: 6))
        #expect(model.pendingMultidayRange == nil)
        #expect(!model.hasMultidaySelection)
    }

    /// Conditions: A range start is staged; the user taps an end date after it, with no
    /// spread matching the resulting range.
    /// Expected: The pending range is completed (start...end), no spread is selected, and
    /// the selection is valid for saving (a spread will be created on save).
    @Test("Completing an unmatched range stages a pending multiday range")
    func completingUnmatchedRangeStagesPendingRange() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        let start = makeDate(year: 2026, month: 7, day: 6)
        let end = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)

        model.handleMultidayDayTap(start, spreads: [])
        model.handleMultidayDayTap(end, spreads: [])

        #expect(model.pendingRangeStart == nil)
        #expect(model.pendingMultidayRange == start...end)
        #expect(model.selectedSpreadID == nil)
        #expect(model.selectedDate == start)
        #expect(model.hasMultidaySelection)
    }

    /// Conditions: A range start is staged; the user taps an end date *before* the start.
    /// Expected: The pending range is normalized so lowerBound <= upperBound.
    @Test("Reversed taps normalize into an ordered range")
    func reversedTapsNormalizeRange() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        let first = makeDate(year: 2026, month: 7, day: 10)
        let second = makeDate(year: 2026, month: 7, day: 6)
        var model = makeModel(today: today)

        model.handleMultidayDayTap(first, spreads: [])
        model.handleMultidayDayTap(second, spreads: [])

        #expect(model.pendingMultidayRange == second...first)
    }

    /// Conditions: A range start is staged; the completed range exactly matches an existing
    /// multiday spread's start and end dates.
    /// Expected: The existing spread is selected instead of staging a pending range.
    @Test("Completing a range matching an existing spread selects it")
    func matchingRangeSelectsExistingSpread() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        let start = makeDate(year: 2026, month: 7, day: 6)
        let end = makeDate(year: 2026, month: 7, day: 10)
        let spread = makeMultidaySpread(start: start, end: end)
        var model = makeModel(today: today)

        // Start on an uncovered date is impossible here (the spread covers start), so stage
        // the start first with no spreads, then complete against the existing spread.
        model.handleMultidayDayTap(start, spreads: [])
        model.handleMultidayDayTap(end, spreads: [spread])

        #expect(model.selectedSpreadID == spread.id)
        #expect(model.pendingMultidayRange == nil)
        #expect(model.pendingRangeStart == nil)
    }

    /// Conditions: A pending range is staged, then the user switches the period to day.
    /// Expected: All pending range state is cleared.
    @Test("Switching period away from multiday clears pending range state")
    func switchingPeriodClearsPendingState() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        var model = makeModel(today: today)
        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 6), spreads: [])
        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 10), spreads: [])

        model.setPeriod(.day)

        #expect(model.pendingRangeStart == nil)
        #expect(model.pendingMultidayRange == nil)
    }

    /// Conditions: A pending range is staged, then the user switches assignment to Inbox.
    /// Expected: Pending range state is cleared alongside the assignment.
    @Test("Disabling preferred assignment clears pending range state")
    func disablingAssignmentClearsPendingState() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        var model = makeModel(today: today)
        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 6), spreads: [])
        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 10), spreads: [])

        model.setPreferredAssignmentEnabled(false)

        #expect(model.pendingRangeStart == nil)
        #expect(model.pendingMultidayRange == nil)
    }

    /// Conditions: Multiday period with no spread and no pending range vs. with a pending range.
    /// Expected: Validation fails with missingMultidaySpread only when neither is present.
    @Test("Validation accepts a pending range as a multiday selection")
    func validationAcceptsPendingRange() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        var model = makeModel(today: today)
        model.title = "Trip prep"

        let withoutSelection = model.validateForSubmission()
        #expect(!withoutSelection)
        #expect(model.dateError == .missingMultidaySpread)

        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 6), spreads: [])
        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 10), spreads: [])

        let withPendingRange = model.validateForSubmission()
        #expect(withPendingRange)
    }

    /// Conditions: Same range-tap flow on `NoteEditorFormModel` (mirrored implementation).
    /// Expected: Identical staging behavior — start, complete, validate.
    @Test("NoteEditorFormModel mirrors the multiday range flow")
    func noteFormModelMirrorsRangeFlow() {
        let today = makeDate(year: 2026, month: 7, day: 4)
        var model = NoteEditorFormModel(
            configuration: EntryCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: nil
        )
        model.title = "Trip notes"
        model.setPeriod(.multiday)

        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 6), spreads: [])
        #expect(model.pendingRangeStart == makeDate(year: 2026, month: 7, day: 6))

        model.handleMultidayDayTap(makeDate(year: 2026, month: 7, day: 10), spreads: [])
        #expect(model.pendingMultidayRange == makeDate(year: 2026, month: 7, day: 6)...makeDate(year: 2026, month: 7, day: 10))
        #expect(model.hasMultidaySelection)
        let isValid = model.validateForSubmission()
        #expect(isValid)
    }
}
