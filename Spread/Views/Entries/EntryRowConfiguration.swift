import Foundation

/// Available swipe actions for entry rows.
enum EntryRowAction: Hashable, Sendable {
    /// Mark a task as complete.
    case complete

    /// Migrate the entry to another spread.
    case migrate

    /// Edit the entry details.
    case edit

    /// Delete the entry.
    case delete
}

/// Configuration for an entry row that determines available actions and display state.
///
/// Encapsulates the logic for determining which swipe actions are available based on
/// entry type and status. This separation enables snapshot-free unit testing of the
/// action availability logic.
struct EntryRowConfiguration: Sendable {

    // MARK: - Properties

    /// The type of entry (task, event, or note).
    let entryType: EntryType

    /// The task status, if this is a task entry.
    let taskStatus: DataModel.Task.Status?

    /// The note status, if this is a note entry.
    let noteStatus: DataModel.Note.Status?

    /// The entry title for display.
    let title: String

    /// The migration destination label, if the entry was migrated.
    let migrationDestination: String?

    /// Whether the event is past (only used for events).
    ///
    /// Computed by the caller based on spread context.
    let isEventPast: Bool

    // MARK: - Initialization

    /// Creates an entry row configuration.
    ///
    /// - Parameters:
    ///   - entryType: The type of entry.
    ///   - taskStatus: The task status (only used for tasks).
    ///   - noteStatus: The note status (only used for notes).
    ///   - title: The entry title (defaults to empty string).
    ///   - migrationDestination: The migration destination label.
    ///   - isEventPast: Whether the event is past (only used for events).
    init(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status? = nil,
        noteStatus: DataModel.Note.Status? = nil,
        title: String = "",
        migrationDestination: String? = nil,
        isEventPast: Bool = false
    ) {
        self.entryType = entryType
        self.taskStatus = taskStatus
        self.noteStatus = noteStatus
        self.title = title
        self.migrationDestination = migrationDestination
        self.isEventPast = isEventPast
    }

    // MARK: - Action Availability

    /// Whether the complete action is available.
    ///
    /// Only tasks with open status can be completed.
    var canComplete: Bool {
        guard entryType == .task, let status = taskStatus else {
            return false
        }
        return status == .open
    }

    /// Whether the migrate action is available.
    ///
    /// Tasks: only open tasks can migrate.
    /// Notes: only active notes can migrate (explicit-only).
    /// Events: never migrate.
    var canMigrate: Bool {
        switch entryType {
        case .task:
            guard let status = taskStatus else { return false }
            return status == .open
        case .note:
            guard let status = noteStatus else { return false }
            return status == .active
        case .event:
            return false
        }
    }

    /// Whether the edit action is available.
    ///
    /// All entry types can be edited.
    var canEdit: Bool {
        true
    }

    /// Whether the delete action is available.
    ///
    /// All entry types can be deleted.
    var canDelete: Bool {
        true
    }

    // MARK: - Swipe Action Collections

    /// Actions available as leading swipe actions.
    ///
    /// Migrate is a leading action for tasks and notes.
    var leadingActions: [EntryRowAction] {
        var actions: [EntryRowAction] = []
        if canMigrate {
            actions.append(.migrate)
        }
        return actions
    }

    /// Actions available as trailing swipe actions.
    ///
    /// Complete is a trailing action for tasks.
    /// Edit and delete are trailing actions for all types.
    var trailingActions: [EntryRowAction] {
        var actions: [EntryRowAction] = []
        if canComplete {
            actions.append(.complete)
        }
        return actions
    }

    // MARK: - Migration Badge

    /// Whether to show a migration badge.
    ///
    /// Shows when a task or note has been migrated and has a destination.
    var showsMigrationBadge: Bool {
        switch entryType {
        case .task:
            return taskStatus == .migrated && migrationDestination != nil
        case .note:
            return noteStatus == .migrated && migrationDestination != nil
        case .event:
            return false
        }
    }

    // MARK: - Visual Styling

    /// Whether the row should be displayed with greyed out styling.
    ///
    /// Returns `true` for:
    /// - Complete tasks
    /// - Migrated tasks
    /// - Migrated notes
    /// - Past events
    var isGreyedOut: Bool {
        switch entryType {
        case .task:
            guard let status = taskStatus else { return false }
            return status == .complete || status == .migrated
        case .note:
            guard let status = noteStatus else { return false }
            return status == .migrated
        case .event:
            return isEventPast
        }
    }

    /// Whether the row should be displayed with strikethrough styling.
    ///
    /// Returns `true` only for cancelled tasks.
    var hasStrikethrough: Bool {
        guard entryType == .task, let status = taskStatus else {
            return false
        }
        return status == .cancelled
    }
}
