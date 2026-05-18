import SwiftUI

/// A type-level configuration describing how entries of one type are displayed and what actions they support.
///
/// One configuration per entry type is stored in `EntryListViewModel.configurationMap`. At render time
/// `EntryRowView` calls each closure with the specific entry to derive per-row values. All business logic —
/// migration resolution, date formatting, persistence callbacks — lives in closures built at the call site.
struct EntryRowConfiguration {

    // MARK: - Context-dependent display derivations

    /// Returns the effective task status, potentially `.migrated` when migration history is shown.
    var effectiveTaskStatus: ((any Entry) -> DataModel.Task.Status?)?

    /// Returns whether the row should render greyed out.
    var isGreyedOut: ((any Entry) -> Bool)?

    /// Returns whether the row title should use strikethrough styling.
    var hasStrikethrough: ((any Entry) -> Bool)?

    /// Returns the migration destination label when the entry was migrated.
    var migrationDestination: ((any Entry) -> String?)?

    /// Returns whether a migration badge should be shown.
    var showsMigrationBadge: ((any Entry) -> Bool)?

    /// Returns the formatted due date label (tasks only).
    var dueDateLabel: ((any Entry) -> String?)?

    /// Returns whether the due date label should use urgent styling.
    var isDueDateHighlighted: ((any Entry) -> Bool)?

    /// Returns whether the event has already ended (events only).
    var isEventPast: ((any Entry) -> Bool)?

    /// Returns the subtitle shown below the title (e.g. event time range + calendar name).
    var subtitle: ((any Entry) -> String?)?

    // MARK: - Action callbacks

    var onComplete: ((any Entry) -> Void)?
    var onEdit: ((any Entry) -> Void)?
    var onDelete: ((any Entry) -> Void)?
    var onTitleCommit: (@MainActor (any Entry, String) async -> Void)?
    var inlineActionConfiguration: ((any Entry) -> EntryRowInlineActionConfiguration?)?
}
