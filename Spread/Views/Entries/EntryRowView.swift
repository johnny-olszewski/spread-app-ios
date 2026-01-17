import SwiftUI

/// A row component for displaying an entry with type symbol, title, and swipe actions.
///
/// Renders the entry with:
/// - StatusIcon (leading) showing entry type and status
/// - Title
/// - Migration badge (if migrated, shows destination)
/// - Swipe actions based on entry type
///
/// Swipe actions by type:
/// - Task: Complete (trailing), Migrate (leading)
/// - Note: Migrate (leading) - explicit only
/// - Event: No migrate action
struct EntryRowView: View {

    // MARK: - Properties

    /// The configuration for this entry row.
    private let configuration: EntryRowConfiguration

    /// The status icon configuration.
    private let iconConfiguration: StatusIconConfiguration

    /// Callback when complete action is triggered.
    private let onComplete: (() -> Void)?

    /// Callback when migrate action is triggered.
    private let onMigrate: (() -> Void)?

    /// Callback when edit action is triggered.
    private let onEdit: (() -> Void)?

    /// Callback when delete action is triggered.
    private let onDelete: (() -> Void)?

    // MARK: - Initialization

    /// Creates an entry row view.
    ///
    /// - Parameters:
    ///   - configuration: The row configuration.
    ///   - iconConfiguration: The status icon configuration.
    ///   - onComplete: Callback for complete action.
    ///   - onMigrate: Callback for migrate action.
    ///   - onEdit: Callback for edit action.
    ///   - onDelete: Callback for delete action.
    init(
        configuration: EntryRowConfiguration,
        iconConfiguration: StatusIconConfiguration,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.iconConfiguration = iconConfiguration
        self.onComplete = onComplete
        self.onMigrate = onMigrate
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    /// Creates an entry row view for a task.
    ///
    /// - Parameters:
    ///   - task: The task to display.
    ///   - migrationDestination: Optional migration destination label.
    ///   - onComplete: Callback for complete action.
    ///   - onMigrate: Callback for migrate action.
    ///   - onEdit: Callback for edit action.
    ///   - onDelete: Callback for delete action.
    init(
        task: DataModel.Task,
        migrationDestination: String? = nil,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.configuration = EntryRowConfiguration(
            entryType: .task,
            taskStatus: task.status,
            title: task.title,
            migrationDestination: migrationDestination
        )
        self.iconConfiguration = StatusIconConfiguration(
            entryType: .task,
            taskStatus: task.status
        )
        self.onComplete = onComplete
        self.onMigrate = onMigrate
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    /// Creates an entry row view for an event.
    ///
    /// - Parameters:
    ///   - event: The event to display.
    ///   - isEventPast: Whether the event is past (computed by caller based on spread context).
    ///   - onEdit: Callback for edit action.
    ///   - onDelete: Callback for delete action.
    init(
        event: DataModel.Event,
        isEventPast: Bool = false,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.configuration = EntryRowConfiguration(
            entryType: .event,
            title: event.title,
            isEventPast: isEventPast
        )
        self.iconConfiguration = StatusIconConfiguration(
            entryType: .event,
            isEventPast: isEventPast
        )
        self.onComplete = nil
        self.onMigrate = nil
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    /// Creates an entry row view for a note.
    ///
    /// - Parameters:
    ///   - note: The note to display.
    ///   - migrationDestination: Optional migration destination label.
    ///   - onMigrate: Callback for migrate action.
    ///   - onEdit: Callback for edit action.
    ///   - onDelete: Callback for delete action.
    init(
        note: DataModel.Note,
        migrationDestination: String? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.configuration = EntryRowConfiguration(
            entryType: .note,
            noteStatus: note.status,
            title: note.title,
            migrationDestination: migrationDestination
        )
        self.iconConfiguration = StatusIconConfiguration(
            entryType: .note,
            noteStatus: note.status
        )
        self.onComplete = nil
        self.onMigrate = onMigrate
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    // MARK: - Body

    var body: some View {
        rowContent
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                leadingSwipeActions
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions
            }
    }

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(spacing: 12) {
            StatusIcon(configuration: iconConfiguration, color: rowColor)

            Text(configuration.title)
                .strikethrough(configuration.hasStrikethrough)
                .lineLimit(2)

            Spacer()

            if configuration.showsMigrationBadge, let destination = configuration.migrationDestination {
                migrationBadge(destination: destination)
            }
        }
        .foregroundStyle(rowColor)
        .contentShape(Rectangle())
    }

    // MARK: - Styling

    private var rowColor: Color {
        if configuration.hasStrikethrough {
            return .secondary
        } else if configuration.isGreyedOut {
            return .secondary
        }
        return .primary
    }

    // MARK: - Migration Badge

    private func migrationBadge(destination: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.caption2)
            Text(destination)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private var leadingSwipeActions: some View {
        if configuration.canMigrate, let onMigrate {
            Button {
                onMigrate()
            } label: {
                Label("Migrate", systemImage: "arrow.right.circle")
            }
            .tint(.orange)
        }
    }

    @ViewBuilder
    private var trailingSwipeActions: some View {
        if configuration.canDelete, let onDelete {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        if configuration.canEdit, let onEdit {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }

        if configuration.canComplete, let onComplete {
            Button {
                onComplete()
            } label: {
                Label("Complete", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
    }
}

// MARK: - Previews

#Preview("Task - Open") {
    List {
        EntryRowView(
            task: DataModel.Task(title: "Buy groceries", status: .open),
            onComplete: {},
            onMigrate: {},
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Task - Complete (Greyed Out)") {
    List {
        EntryRowView(
            task: DataModel.Task(title: "File taxes", status: .complete),
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Task - Migrated (Greyed Out)") {
    List {
        EntryRowView(
            task: DataModel.Task(title: "Call dentist", status: .migrated),
            migrationDestination: "January 2026",
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Task - Cancelled (Strikethrough)") {
    List {
        EntryRowView(
            task: DataModel.Task(title: "Buy a boat", status: .cancelled),
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Event - Current") {
    List {
        EntryRowView(
            event: DataModel.Event(title: "Team meeting"),
            isEventPast: false,
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Event - Past (Greyed Out)") {
    List {
        EntryRowView(
            event: DataModel.Event(title: "Yesterday's standup"),
            isEventPast: true,
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Note - Active") {
    List {
        EntryRowView(
            note: DataModel.Note(title: "Project ideas", status: .active),
            onMigrate: {},
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("Note - Migrated (Greyed Out)") {
    List {
        EntryRowView(
            note: DataModel.Note(title: "Meeting notes", status: .migrated),
            migrationDestination: "February 2026",
            onEdit: {},
            onDelete: {}
        )
    }
}

#Preview("All Entry States") {
    List {
        Section("Tasks") {
            EntryRowView(
                task: DataModel.Task(title: "Open task", status: .open),
                onComplete: {},
                onMigrate: {}
            )
            EntryRowView(
                task: DataModel.Task(title: "Complete task (greyed)", status: .complete)
            )
            EntryRowView(
                task: DataModel.Task(title: "Migrated task (greyed)", status: .migrated),
                migrationDestination: "Next Month"
            )
            EntryRowView(
                task: DataModel.Task(title: "Cancelled task (strikethrough)", status: .cancelled)
            )
        }

        Section("Events") {
            EntryRowView(
                event: DataModel.Event(title: "Current event"),
                isEventPast: false
            )
            EntryRowView(
                event: DataModel.Event(title: "Past event (greyed)"),
                isEventPast: true
            )
        }

        Section("Notes") {
            EntryRowView(
                note: DataModel.Note(title: "Active note", status: .active),
                onMigrate: {}
            )
            EntryRowView(
                note: DataModel.Note(title: "Migrated note (greyed)", status: .migrated),
                migrationDestination: "Next Year"
            )
        }
    }
}

#Preview("Visual Treatment Comparison") {
    List {
        Section("Normal vs Greyed Out") {
            EntryRowView(
                task: DataModel.Task(title: "Normal styling", status: .open)
            )
            EntryRowView(
                task: DataModel.Task(title: "Greyed out styling", status: .complete)
            )
        }

        Section("Normal vs Strikethrough") {
            EntryRowView(
                task: DataModel.Task(title: "Normal styling", status: .open)
            )
            EntryRowView(
                task: DataModel.Task(title: "Strikethrough styling", status: .cancelled)
            )
        }
    }
}
