import Testing
@testable import Spread

/// Accessibility label and value tests for `EntryRowView`.
///
/// Since accessibility computation is now inside `EntryRowView` as private computed
/// properties (not on `EntryRowView.Configuration`), these tests verify the `Entry` display
/// protocol requirements that feed the accessibility computation.
struct EntryRowAccessibilityTests {

    // MARK: - Entry display requirements

    /// Conditions: Task with open status.
    /// Expected: displayTaskStatus returns .open.
    @Test func taskWithOpenStatus_displayTaskStatus_isOpen() {
        let task = DataModel.Task(title: "Buy milk", status: .open)

        #expect(task.displayTaskStatus == .open)
    }

    /// Conditions: Task with complete status.
    /// Expected: displayTaskStatus returns .complete.
    @Test func taskWithCompleteStatus_displayTaskStatus_isComplete() {
        let task = DataModel.Task(title: "Buy milk", status: .complete)

        #expect(task.displayTaskStatus == .complete)
    }

    /// Conditions: Task with high priority.
    /// Expected: displayPriority returns .high.
    @Test func taskWithHighPriority_displayPriority_isHigh() {
        let task = DataModel.Task(title: "Buy milk", priority: .high, status: .open)

        #expect(task.displayPriority == .high)
    }

    /// Conditions: Note with active status.
    /// Expected: displayNoteStatus returns .active.
    @Test func noteWithActiveStatus_displayNoteStatus_isActive() {
        let note = DataModel.Note(title: "Ideas", status: .active)

        #expect(note.displayNoteStatus == .active)
    }

    /// Conditions: Default Entry (task with no explicit priority).
    /// Expected: displayPriority returns .none from the default protocol extension.
    @Test func taskWithNoPriority_displayPriority_isNone() {
        let task = DataModel.Task(title: "Buy milk", status: .open)

        #expect(task.displayPriority == .none)
    }
}
