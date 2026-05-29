import Testing
@testable import Spread

struct EntryStatusPresentationTests {

    @Test func userEditableTaskStatusesExcludeMigrated() {
        #expect(EntryStatus.userEditableTaskStatuses == [.open, .complete, .cancelled])
    }

    @Test func cancelledTaskDisablesAssignmentEditingInTaskSheet() {
        #expect(EntryStatus.cancelled.allowsAssignmentEditingInTaskSheet == false)
        #expect(EntryStatus.complete.allowsAssignmentEditingInTaskSheet == false)
        #expect(EntryStatus.open.allowsAssignmentEditingInTaskSheet == true)
    }

    @Test func taskLifecycleActionsMatchTaskSheetBehavior() {
        #expect(EntryStatus.open.lifecycleActionTitleInTaskSheet == "Cancel Task")
        #expect(EntryStatus.complete.lifecycleActionTitleInTaskSheet == "Cancel Task")
        #expect(EntryStatus.cancelled.lifecycleActionTitleInTaskSheet == "Restore Task")
        #expect(EntryStatus.migrated.lifecycleActionTitleInTaskSheet == nil)
    }
}
