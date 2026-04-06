import Foundation
import Testing
@testable import Spread

/// Tests for SpreadsCoordinator action methods and sheet destination management.
@Suite("SpreadsCoordinator Tests")
@MainActor
struct SpreadsCoordinatorTests {

    // MARK: - Initial State

    /// Condition: Coordinator is freshly created.
    /// Expected: No active sheet.
    @Test("Initial state has no active sheet")
    func testInitialStateHasNoActiveSheet() {
        let coordinator = SpreadsCoordinator()
        #expect(coordinator.activeSheet == nil)
    }

    // MARK: - Action Methods

    /// Condition: Call showSpreadCreation().
    /// Expected: Active sheet is .spreadCreation.
    @Test("showSpreadCreation sets spreadCreation destination")
    func testShowSpreadCreation() {
        let coordinator = SpreadsCoordinator()
        coordinator.showSpreadCreation()
        guard case .spreadCreation(_) = coordinator.activeSheet else {
            Issue.record("Expected .spreadCreation, got \(String(describing: coordinator.activeSheet))")
            return
        }
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

    /// Condition: Call showInbox().
    /// Expected: Active sheet is .inbox.
    @Test("showInbox sets inbox destination")
    func testShowInbox() {
        let coordinator = SpreadsCoordinator()
        coordinator.showInbox()
        guard case .inbox = coordinator.activeSheet else {
            Issue.record("Expected .inbox, got \(String(describing: coordinator.activeSheet))")
            return
        }
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
        coordinator.showInbox()
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
        coordinator.showInbox()
        guard case .inbox = coordinator.activeSheet else {
            Issue.record("Expected .inbox")
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

        let destinations: [SpreadsCoordinator.SheetDestination] = [
            .spreadCreation(nil),
            .taskCreation,
            .noteCreation,
            .taskDetail(task),
            .noteDetail(note),
            .inbox,
            .auth
        ]

        let ids = destinations.map(\.id)
        let uniqueIds = Set(ids)
        #expect(uniqueIds.count == destinations.count)
    }
}
