import SwiftUI

/// Manages all presentation state for `TaskEntrySheet`.
///
/// Owns the four sheet/alert destinations that can be active at once:
/// spread picker, delete confirmation (handled by `EntrySheet`), and
/// the list/tag creation alerts in the metadata section.
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

    var isCreatingList = false
    var newListName = ""

    var isCreatingTag = false
    var newTagName = ""

    var isTagsExpanded = false

    // MARK: - Actions

    func showSpreadPicker() {
        activeSheet = .spreadPicker
    }

    func dismissSheet() {
        activeSheet = nil
    }
}
