import Foundation
import Testing
@testable import Spread

/// Tests for SpreadsCoordinator shell state transitions.
@Suite("SpreadsCoordinator Tests")
@MainActor
struct SpreadsCoordinatorTests {

    // MARK: - Initial State

    /// Condition: ViewModel is freshly created.
    /// Expected: No active sheet, no selected selection, recenter token is 0.
    @Test("Initial state has no active sheet and no selection")
    func testInitialState() {
        let coordinator = SpreadsCoordinator()
        #expect(coordinator.activeSheet == nil)
        #expect(coordinator.activeAlert == nil)
        #expect(coordinator.selectedSelection == nil)
        #expect(coordinator.recenterToken == 0)
    }

    // MARK: - Sheet Actions

    /// Condition: Call showSpreadCreation() without prefill.
    /// Expected: Active sheet is .spreadCreation with nil prefill.
    @Test("showSpreadCreation sets spreadCreation destination")
    func testShowSpreadCreation() {
        let coordinator = SpreadsCoordinator()
        coordinator.showSpreadCreation()
        guard case .spreadCreation(let prefill) = coordinator.activeSheet else {
            Issue.record("Expected .spreadCreation, got \(String(describing: coordinator.activeSheet))")
            return
        }
        #expect(prefill == nil)
    }

    /// Condition: Call showSpreadCreation(prefill:) with a specific period and date.
    /// Expected: Active sheet is .spreadCreation carrying the prefill.
    @Test("showSpreadCreation with prefill sets prefill on destination")
    func testShowSpreadCreationWithPrefill() {
        let coordinator = SpreadsCoordinator()
        let date = Date(timeIntervalSince1970: 0)
        coordinator.showSpreadCreation(prefill: .init(period: .day, date: date))
        guard case .spreadCreation(let prefill) = coordinator.activeSheet else {
            Issue.record("Expected .spreadCreation, got \(String(describing: coordinator.activeSheet))")
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
        let coordinator = SpreadsCoordinator()

        coordinator.showSpreadNameEdit(spread)

        guard case .spreadNameEdit(let destinationSpread) = coordinator.activeSheet else {
            Issue.record("Expected .spreadNameEdit, got \(String(describing: coordinator.activeSheet))")
            return
        }
        #expect(destinationSpread.id == spread.id)
    }

    /// Condition: Call showSpreadDateEdit() with a persisted multiday spread.
    /// Expected: Active sheet is .spreadDateEdit carrying the same spread identity.
    @Test("showSpreadDateEdit sets spreadDateEdit destination")
    func testShowSpreadDateEdit() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 18))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 24))!
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let coordinator = SpreadsCoordinator()

        coordinator.showSpreadDateEdit(spread)

        guard case .spreadDateEdit(let destinationSpread) = coordinator.activeSheet else {
            Issue.record("Expected .spreadDateEdit, got \(String(describing: coordinator.activeSheet))")
            return
        }
        #expect(destinationSpread.id == spread.id)
    }

    /// Condition: A multiday date edit saves with an updated spread instance.
    /// Expected: Selection stays on that spread identity and recenterToken increments.
    @Test("finishSpreadDateEdit keeps edited spread selected and recenters")
    func testFinishSpreadDateEditKeepsSelectionAndRecenters() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let startDate = calendar.date(from: .init(year: 2026, month: 12, day: 28))!
        let endDate = calendar.date(from: .init(year: 2027, month: 1, day: 3))!
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let coordinator = SpreadsCoordinator()
        coordinator.recenterToken = 2

        coordinator.finishSpreadDateEdit(spread)

        guard case .conventional(let selectedSpread) = coordinator.selectedSelection else {
            Issue.record("Expected conventional selection")
            return
        }
        #expect(selectedSpread.id == spread.id)
        #expect(coordinator.recenterToken == 3)
    }

    /// Condition: Call showSpreadDeleteConfirmation with a selected spread.
    /// Expected: Active alert is .deleteSpreadConfirmation and carries that spread without changing selection.
    @Test("showSpreadDeleteConfirmation sets delete confirmation alert")
    func testShowSpreadDeleteConfirmation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let spread = DataModel.Spread(period: .day, date: Date(timeIntervalSince1970: 0), calendar: calendar)
        let coordinator = SpreadsCoordinator()
        coordinator.selectedSelection = .conventional(spread)

        coordinator.showSpreadDeleteConfirmation(spread)

        guard case .deleteSpreadConfirmation(let destinationSpread) = coordinator.activeAlert else {
            Issue.record("Expected .deleteSpreadConfirmation, got \(String(describing: coordinator.activeAlert))")
            return
        }
        #expect(destinationSpread.id == spread.id)
        guard case .conventional(let selectedSpread) = coordinator.selectedSelection else {
            Issue.record("Expected conventional selection")
            return
        }
        #expect(selectedSpread.id == spread.id)
    }

    /// Condition: A delete confirmation alert is active, then dismissAlert() is called as the cancel path.
    /// Expected: The alert clears and the current spread selection is unchanged.
    @Test("dismissAlert clears delete confirmation without changing selection")
    func testDismissAlertClearsDeleteConfirmationWithoutChangingSelection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let spread = DataModel.Spread(period: .day, date: Date(timeIntervalSince1970: 0), calendar: calendar)
        let coordinator = SpreadsCoordinator()
        coordinator.selectedSelection = .conventional(spread)
        coordinator.showSpreadDeleteConfirmation(spread)

        coordinator.dismissAlert()

        #expect(coordinator.activeAlert == nil)
        guard case .conventional(let selectedSpread) = coordinator.selectedSelection else {
            Issue.record("Expected conventional selection")
            return
        }
        #expect(selectedSpread.id == spread.id)
    }

    /// Condition: A spread deletion attempt fails.
    /// Expected: The failure alert stores the user-facing message without changing selection.
    @Test("showSpreadDeleteFailure presents error without changing selection")
    func testShowSpreadDeleteFailure() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let spread = DataModel.Spread(period: .month, date: Date(timeIntervalSince1970: 0), calendar: calendar)
        let coordinator = SpreadsCoordinator()
        coordinator.selectedSelection = .conventional(spread)

        coordinator.showSpreadDeleteFailure(message: "Failed to delete spread: forced failure")

        guard case .deleteSpreadFailed(let message) = coordinator.activeAlert else {
            Issue.record("Expected .deleteSpreadFailed, got \(String(describing: coordinator.activeAlert))")
            return
        }
        #expect(message == "Failed to delete spread: forced failure")
        guard case .conventional(let selectedSpread) = coordinator.selectedSelection else {
            Issue.record("Expected conventional selection")
            return
        }
        #expect(selectedSpread.id == spread.id)
    }

    /// Condition: Call showTaskCreation().
    /// Expected: Active sheet is .taskCreation.
    @Test("showTaskCreation sets taskCreation destination")
    func testShowTaskCreation() {
        let coordinator = SpreadsCoordinator()
        coordinator.showTaskCreation()
        guard case .taskCreation = coordinator.activeSheet else {
            Issue.record("Expected .taskCreation, got \(String(describing: coordinator.activeSheet))")
            return
        }
    }

    /// Condition: Call showNoteCreation().
    /// Expected: Active sheet is .noteCreation.
    @Test("showNoteCreation sets noteCreation destination")
    func testShowNoteCreation() {
        let coordinator = SpreadsCoordinator()
        coordinator.showNoteCreation()
        guard case .noteCreation = coordinator.activeSheet else {
            Issue.record("Expected .noteCreation, got \(String(describing: coordinator.activeSheet))")
            return
        }
    }

    /// Condition: Call showTaskDetail with a task.
    /// Expected: Active sheet is .taskDetail with the correct task.
    @Test("showTaskDetail sets taskDetail destination with task")
    func testShowTaskDetail() {
        let coordinator = SpreadsCoordinator()
        let task = DataModel.Task(
            title: "Test task",
            createdDate: .now,
            date: .now,
            period: .day,
            status: .open
        )

        coordinator.showTaskDetail(task)

        guard case .taskDetail(let detailTask) = coordinator.activeSheet else {
            Issue.record("Expected .taskDetail, got \(String(describing: coordinator.activeSheet))")
            return
        }
        #expect(detailTask.id == task.id)
    }

    /// Condition: Call showNoteDetail with a note.
    /// Expected: Active sheet is .noteDetail with the correct note.
    @Test("showNoteDetail sets noteDetail destination with note")
    func testShowNoteDetail() {
        let coordinator = SpreadsCoordinator()
        let note = DataModel.Note(
            title: "Test note",
            date: .now,
            period: .day
        )

        coordinator.showNoteDetail(note)

        guard case .noteDetail(let detailNote) = coordinator.activeSheet else {
            Issue.record("Expected .noteDetail, got \(String(describing: coordinator.activeSheet))")
            return
        }
        #expect(detailNote.id == note.id)
    }

    /// Condition: Call showAuth().
    /// Expected: Active sheet is .auth.
    @Test("showAuth sets auth destination")
    func testShowAuth() {
        let coordinator = SpreadsCoordinator()
        coordinator.showAuth()
        guard case .auth = coordinator.activeSheet else {
            Issue.record("Expected .auth, got \(String(describing: coordinator.activeSheet))")
            return
        }
    }

    // MARK: - Dismiss

    /// Condition: A sheet is active, then dismiss() is called.
    /// Expected: Active sheet becomes nil.
    @Test("dismiss clears the active sheet")
    func testDismissClearsActiveSheet() {
        let coordinator = SpreadsCoordinator()
        coordinator.showTaskCreation()
        #expect(coordinator.activeSheet != nil)

        coordinator.dismiss()

        #expect(coordinator.activeSheet == nil)
    }

    // MARK: - Single Sheet Guarantee

    /// Condition: One sheet is active, then a different action is called.
    /// Expected: The new destination replaces the old one.
    @Test("Showing a new sheet replaces the current one")
    func testShowingNewSheetReplacesCurrentOne() {
        let coordinator = SpreadsCoordinator()
        coordinator.showTaskCreation()
        guard case .taskCreation = coordinator.activeSheet else {
            Issue.record("Expected .taskCreation")
            return
        }

        coordinator.showAuth()

        guard case .auth = coordinator.activeSheet else {
            Issue.record("Expected .auth after replacement, got \(String(describing: coordinator.activeSheet))")
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

        let destinations: [SpreadsCoordinator.SheetDestination] = [
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

    /// Condition: Different alert destinations are created.
    /// Expected: Alert destinations have stable unique identifiers.
    @Test("Alert destinations have unique identifiers")
    func testAlertDestinationsHaveUniqueIdentifiers() {
        let spread = DataModel.Spread(period: .day, date: .now, calendar: Calendar(identifier: .gregorian))
        let destinations: [SpreadsCoordinator.AlertDestination] = [
            .deleteSpreadConfirmation(spread),
            .deleteSpreadFailed(message: "Failure")
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
        let coordinator = SpreadsCoordinator()
        #expect(coordinator.recenterToken == 0)
        coordinator.recenterToken += 1
        #expect(coordinator.recenterToken == 1)
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

        let coordinator = SpreadsCoordinator()
        #expect(coordinator.selectedSelection == nil)

        coordinator.selectedSelection = .conventional(spread)

        guard case .conventional(let stored) = coordinator.selectedSelection else {
            Issue.record("Expected .conventional selection")
            return
        }
        #expect(stored.id == spread.id)
    }

    /// Condition: Creating a month spread from the selected parent year triggers auto-migration.
    /// Expected: Selection stays on the year surface and a local month-card feedback cue is stored.
    @Test("finishSpreadCreation keeps parent selection for local year to month reveal")
    func testFinishSpreadCreationKeepsParentSelectionForLocalReveal() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let year = DataModel.Spread(period: .year, date: calendar.date(from: .init(year: 2026, month: 1, day: 1))!, calendar: calendar)
        let month = DataModel.Spread(period: .month, date: calendar.date(from: .init(year: 2026, month: 3, day: 1))!, calendar: calendar)
        let coordinator = SpreadsCoordinator()
        let currentSelection = SpreadHeaderNavigatorModel.Selection.conventional(year)
        coordinator.selectedSelection = currentSelection

        coordinator.finishSpreadCreation(
            .init(
                spread: month,
                autoMigrationSummary: .init(taskCount: 1, noteCount: 1)
            ),
            currentSelection: currentSelection,
            calendar: calendar
        )

        guard case .conventional(let selectedSpread)? = coordinator.selectedSelection else {
            Issue.record("Expected conventional selection")
            return
        }
        #expect(selectedSpread.id == year.id)
        #expect(coordinator.autoMigrationFeedback?.surfaceSpreadID == year.id)
    }

    /// Condition: Creating a day spread from a multiday surface triggers auto-migration.
    /// Expected: Selection navigates to the created day destination and stores header-level feedback.
    @Test("finishSpreadCreation navigates when local reveal is unavailable")
    func testFinishSpreadCreationNavigatesWhenLocalRevealIsUnavailable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        let multiday = DataModel.Spread(
            startDate: calendar.date(from: .init(year: 2026, month: 3, day: 10))!,
            endDate: calendar.date(from: .init(year: 2026, month: 3, day: 16))!,
            calendar: calendar
        )
        let day = DataModel.Spread(period: .day, date: calendar.date(from: .init(year: 2026, month: 3, day: 14))!, calendar: calendar)
        let coordinator = SpreadsCoordinator()

        coordinator.finishSpreadCreation(
            .init(
                spread: day,
                autoMigrationSummary: .init(taskCount: 2, noteCount: 0)
            ),
            currentSelection: .conventional(multiday),
            calendar: calendar
        )

        guard case .conventional(let selectedSpread)? = coordinator.selectedSelection else {
            Issue.record("Expected conventional destination selection")
            return
        }
        #expect(selectedSpread.id == day.id)
        #expect(coordinator.autoMigrationFeedback?.surfaceSpreadID == day.id)
        #expect(coordinator.autoMigrationFeedback?.anchor == .spreadHeader)
    }
}
