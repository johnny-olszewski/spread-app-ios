import Testing
@testable import Spread

struct EntryStatusPresentationTests {

    @Test func userEditableTaskStatusesExcludeMigrated() {
        #expect(DataModel.Task.Status.userEditableTaskStatuses == [.open, .complete, .cancelled])
    }

    @Test func completeTaskStatusSharesOverlaySymbolWithStatusIconConfiguration() {
        let configuration = StatusIconConfiguration(entryType: .task, taskStatus: .complete)

        #expect(configuration.overlaySymbol == DataModel.Task.Status.complete.statusIconOverlaySymbol)
    }

    @Test func cancelledTaskDisablesAssignmentEditingInTaskSheet() {
        #expect(DataModel.Task.Status.cancelled.allowsAssignmentEditingInTaskSheet == false)
        #expect(DataModel.Task.Status.complete.allowsAssignmentEditingInTaskSheet == false)
        #expect(DataModel.Task.Status.open.allowsAssignmentEditingInTaskSheet == true)
    }

    @Test func taskLifecycleActionsMatchTaskSheetBehavior() {
        #expect(DataModel.Task.Status.open.lifecycleActionTitleInTaskSheet == "Cancel Task")
        #expect(DataModel.Task.Status.complete.lifecycleActionTitleInTaskSheet == "Cancel Task")
        #expect(DataModel.Task.Status.cancelled.lifecycleActionTitleInTaskSheet == "Restore Task")
        #expect(DataModel.Task.Status.migrated.lifecycleActionTitleInTaskSheet == nil)
    }
}
