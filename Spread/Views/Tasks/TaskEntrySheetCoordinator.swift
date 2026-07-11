import SwiftUI

/// Manages presentation state for `TaskEntrySheet`.
///
/// Spread selection is embedded in the assignment calendar and list/tag creation is
/// inline in the chip clouds, so the only remaining state is the due-date calendar and
/// scheduled-time picker expansions. Delete confirmation is handled by `EntrySheet`.
@Observable @MainActor final class TaskEntrySheetCoordinator {

    /// Whether the inline due-date calendar is expanded below the due-date value chip.
    var isDueDateCalendarVisible = false

    /// Whether the inline scheduled-time picker is expanded below the time value chip. [SPRD-299]
    var isScheduledTimePickerVisible = false
}
