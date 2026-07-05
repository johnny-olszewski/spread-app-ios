import SwiftUI

/// Manages all presentation state for `TaskEntrySheet`.
///
/// Owns the spread picker sheet destination and the inline due-date calendar
/// expansion state. List/tag creation is inline in the chip clouds (no alerts),
/// and delete confirmation is handled by `EntrySheet`.
@Observable @MainActor final class TaskEntrySheetCoordinator {

    // MARK: - Sheet Destination

    enum SheetDestination: Identifiable {
        case spreadPicker

        var id: Int {
            switch self {
            case .spreadPicker: return 0
            }
        }
    }

    // MARK: - State

    var activeSheet: SheetDestination?

    // Alert-based list/tag creation state — used only by `NoteEntrySheet` until it
    // migrates to inline chip-cloud creation.
    // - TODO: [SPRD-293] Remove once NoteEntrySheet adopts EntrySheetChipCloud.
    var isCreatingList = false
    var newListName = ""

    var isCreatingTag = false
    var newTagName = ""

    var isTagsExpanded = false

    /// Whether the inline due-date calendar is expanded below the due-date value chip.
    var isDueDateCalendarVisible = false

    // MARK: - Actions

    func showSpreadPicker() {
        activeSheet = .spreadPicker
    }

    func dismissSheet() {
        activeSheet = nil
    }
}
