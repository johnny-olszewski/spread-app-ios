import Foundation
import Testing
@testable import Spread

/// Tests for SpreadsViewModel shell state transitions.
@Suite("SpreadsViewModel Tests")
@MainActor
struct SpreadsViewModelTests {

    // MARK: - Initial State

    /// Condition: ViewModel is freshly created.
    /// Expected: No active sheet, no selected selection, recenter token is 0.
    @Test("Initial state has no active sheet and no selection")
    func testInitialState() {
        let viewModel = SpreadsViewModel()
        #expect(viewModel.activeSheet == nil)
        #expect(viewModel.selectedSelection == nil)
        #expect(viewModel.recenterToken == 0)
    }

    // MARK: - Sheet Actions

    /// Condition: Call showSpreadCreation() without prefill.
    /// Expected: Active sheet is .spreadCreation with nil prefill.
    @Test("showSpreadCreation sets spreadCreation destination")
    func testShowSpreadCreation() {
        let viewModel = SpreadsViewModel()
        viewModel.showSpreadCreation()
        guard case .spreadCreation(let prefill) = viewModel.activeSheet else {
            Issue.record("Expected .spreadCreation, got \(String(describing: viewModel.activeSheet))")
            return
        }
        #expect(prefill == nil)
    }

    /// Condition: Call showSpreadCreation(prefill:) with a specific period and date.
    /// Expected: Active sheet is .spreadCreation carrying the prefill.
    @Test("showSpreadCreation with prefill sets prefill on destination")
    func testShowSpreadCreationWithPrefill() {
        let viewModel = SpreadsViewModel()
        let date = Date(timeIntervalSince1970: 0)
        viewModel.showSpreadCreation(prefill: .init(period: .day, date: date))
        guard case .spreadCreation(let prefill) = viewModel.activeSheet else {
            Issue.record("Expected .spreadCreation, got \(String(describing: viewModel.activeSheet))")
            return
        }
        #expect(prefill?.period == .day)
        #expect(prefill?.date == date)
    }

    @Test("showSpreadNameEdit sets spreadNameEdit destination")
    func testShowSpreadNameEdit() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let spread = DataModel.Spread(period: .day, date: Date(timeIntervalSince1970: 0), calendar: calendar)
        let viewModel = SpreadsViewModel()

        viewModel.showSpreadNameEdit(spread)

        guard case .spreadNameEdit(let destinationSpread) = viewModel.activeSheet else {
            Issue.record("Expected .spreadNameEdit, got \(String(describing: viewModel.activeSheet))")
            return
        }
        #expect(destinationSpread.id == spread.id)
    }

    /// Condition: Call showTaskCreation().
    /// Expected: Active sheet is .taskCreation.
    @Test("showTaskCreation sets taskCreation destination")
    func testShowTaskCreation() {
        let viewModel = SpreadsViewModel()
        viewModel.showTaskCreation()
        guard case .taskCreation = viewModel.activeSheet else {
            Issue.record("Expected .taskCreation, got \(String(describing: viewModel.activeSheet))")
            return
        }
    }

    /// Condition: Call showNoteCreation().
    /// Expected: Active sheet is .noteCreation.
    @Test("showNoteCreation sets noteCreation destination")
    func testShowNoteCreation() {
        let viewModel = SpreadsViewModel()
        viewModel.showNoteCreation()
        guard case .noteCreation = viewModel.activeSheet else {
            Issue.record("Expected .noteCreation, got \(String(describing: viewModel.activeSheet))")
            return
        }
    }

    /// Condition: Call showTaskDetail with a task.
    /// Expected: Active sheet is .taskDetail with the correct task.
    @Test("showTaskDetail sets taskDetail destination with task")
    func testShowTaskDetail() {
        let viewModel = SpreadsViewModel()
        let task = DataModel.Task(
            title: "Test task",
            createdDate: .now,
            date: .now,
            period: .day,
            status: .open
        )

        viewModel.showTaskDetail(task)

        guard case .taskDetail(let detailTask) = viewModel.activeSheet else {
            Issue.record("Expected .taskDetail, got \(String(describing: viewModel.activeSheet))")
            return
        }
        #expect(detailTask.id == task.id)
    }

    /// Condition: Call showNoteDetail with a note.
    /// Expected: Active sheet is .noteDetail with the correct note.
    @Test("showNoteDetail sets noteDetail destination with note")
    func testShowNoteDetail() {
        let viewModel = SpreadsViewModel()
        let note = DataModel.Note(
            title: "Test note",
            date: .now,
            period: .day
        )

        viewModel.showNoteDetail(note)

        guard case .noteDetail(let detailNote) = viewModel.activeSheet else {
            Issue.record("Expected .noteDetail, got \(String(describing: viewModel.activeSheet))")
            return
        }
        #expect(detailNote.id == note.id)
    }

    /// Condition: Call showAuth().
    /// Expected: Active sheet is .auth.
    @Test("showAuth sets auth destination")
    func testShowAuth() {
        let viewModel = SpreadsViewModel()
        viewModel.showAuth()
        guard case .auth = viewModel.activeSheet else {
            Issue.record("Expected .auth, got \(String(describing: viewModel.activeSheet))")
            return
        }
    }

    // MARK: - Dismiss

    /// Condition: A sheet is active, then dismiss() is called.
    /// Expected: Active sheet becomes nil.
    @Test("dismiss clears the active sheet")
    func testDismissClearsActiveSheet() {
        let viewModel = SpreadsViewModel()
        viewModel.showTaskCreation()
        #expect(viewModel.activeSheet != nil)

        viewModel.dismiss()

        #expect(viewModel.activeSheet == nil)
    }

    // MARK: - Single Sheet Guarantee

    /// Condition: One sheet is active, then a different action is called.
    /// Expected: The new destination replaces the old one.
    @Test("Showing a new sheet replaces the current one")
    func testShowingNewSheetReplacesCurrentOne() {
        let viewModel = SpreadsViewModel()
        viewModel.showTaskCreation()
        guard case .taskCreation = viewModel.activeSheet else {
            Issue.record("Expected .taskCreation")
            return
        }

        viewModel.showAuth()

        guard case .auth = viewModel.activeSheet else {
            Issue.record("Expected .auth after replacement, got \(String(describing: viewModel.activeSheet))")
            return
        }
    }

    // MARK: - SheetDestination Identifiable

    /// Condition: Each sheet destination produces a unique id.
    /// Expected: Different destinations have different ids.
    @Test("Sheet destinations have unique identifiers")
    func testSheetDestinationsHaveUniqueIdentifiers() {
        let task = DataModel.Task(
            title: "Task",
            createdDate: .now,
            date: .now,
            period: .day,
            status: .open
        )
        let note = DataModel.Note(title: "Note", date: .now, period: .day)
        let spread = DataModel.Spread(period: .day, date: .now, calendar: Calendar(identifier: .gregorian))

        let destinations: [SpreadsViewModel.SheetDestination] = [
            .spreadCreation(nil),
            .spreadNameEdit(spread),
            .taskCreation,
            .noteCreation,
            .taskDetail(task),
            .noteDetail(note),
            .auth
        ]

        let ids = destinations.map(\.id)
        let uniqueIds = Set(ids)
        #expect(uniqueIds.count == destinations.count)
    }

    // MARK: - Recenter Token

    /// Condition: recenterToken starts at 0 and is incremented manually.
    /// Expected: Value reflects direct mutations.
    @Test("recenterToken increments correctly")
    func testRecenterTokenIncrements() {
        let viewModel = SpreadsViewModel()
        #expect(viewModel.recenterToken == 0)
        viewModel.recenterToken += 1
        #expect(viewModel.recenterToken == 1)
    }

    // MARK: - Selected Selection

    /// Condition: selectedSelection starts nil and is set to a conventional selection.
    /// Expected: Value is stored and retrievable.
    @Test("selectedSelection stores and returns set value")
    func testSelectedSelectionStoresValue() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let date = calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        let spread = DataModel.Spread(period: .year, date: date, calendar: calendar)

        let viewModel = SpreadsViewModel()
        #expect(viewModel.selectedSelection == nil)

        viewModel.selectedSelection = .conventional(spread)

        guard case .conventional(let stored) = viewModel.selectedSelection else {
            Issue.record("Expected .conventional selection")
            return
        }
        #expect(stored.id == spread.id)
    }
}
