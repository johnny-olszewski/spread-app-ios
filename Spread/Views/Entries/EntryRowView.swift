import SwiftUI

/// A row component for displaying an entry with type symbol, title, and swipe actions.
///
/// Renders the entry with:
/// - StatusIcon (leading) showing entry type and status
/// - Title
/// - Migration badge (if migrated, shows destination)
/// - Swipe actions based on entry type
///
/// For tasks, tapping the title activates inline editing. The full edit sheet is
/// accessible via the Edit swipe action. Swipe actions are suppressed while editing.
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

    /// Callback when the user commits an inline title edit (tasks only).
    /// Receives the trimmed, non-empty new title.
    private let onTitleCommit: ((String) -> Void)?

    /// Whether tapping the row should invoke edit (for non-task entries).
    private let opensEditOnTap: Bool

    // MARK: - Inline edit state

    @State private var isEditingTitle: Bool = false
    @State private var editingText: String = ""
    @FocusState private var isTitleFocused: Bool

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
    ///   - onTitleCommit: Callback for inline title commit (tasks only).
    ///   - opensEditOnTap: Whether tapping the row invokes edit.
    init(
        configuration: EntryRowConfiguration,
        iconConfiguration: StatusIconConfiguration,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: ((String) -> Void)? = nil,
        opensEditOnTap: Bool = false
    ) {
        self.configuration = configuration
        self.iconConfiguration = iconConfiguration
        self.onComplete = onComplete
        self.onMigrate = onMigrate
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = onTitleCommit
        self.opensEditOnTap = opensEditOnTap
    }

    /// Creates an entry row view for a task.
    init(
        task: DataModel.Task,
        migrationDestination: String? = nil,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: ((String) -> Void)? = nil,
        opensEditOnTap: Bool = false
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
        self.onTitleCommit = onTitleCommit
        self.opensEditOnTap = opensEditOnTap
    }

    /// Creates an entry row view for an event.
    init(
        event: DataModel.Event,
        isEventPast: Bool = false,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        opensEditOnTap: Bool = false
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
        self.onTitleCommit = nil
        self.opensEditOnTap = opensEditOnTap
    }

    /// Creates an entry row view for a note.
    init(
        note: DataModel.Note,
        migrationDestination: String? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        opensEditOnTap: Bool = false
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
        self.onTitleCommit = nil
        self.opensEditOnTap = opensEditOnTap
    }

    // MARK: - Body

    var body: some View {
        if isEditingTitle {
            editingRowContent
        } else {
            rowContent
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    leadingSwipeActions
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    trailingSwipeActions
                }
        }
    }

    // MARK: - Row Content

    private var rowContent: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(configuration: iconConfiguration, color: rowColor)

            Text(configuration.title)
                .strikethrough(configuration.hasStrikethrough)
                .lineLimit(2)
                .onTapGesture {
                    guard configuration.entryType == .task,
                          onTitleCommit != nil,
                          configuration.taskStatus == .open else { return }
                    beginEditing()
                }

            Spacer()

            if configuration.showsMigrationBadge, let destination = configuration.migrationDestination {
                migrationBadge(destination: destination)
            }
        }
        .foregroundStyle(rowColor)
        .contentShape(Rectangle())
        .onTapGesture {
            guard configuration.entryType != .task else { return }
            guard opensEditOnTap else { return }
            onEdit?()
        }
    }

    private var editingRowContent: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(configuration: iconConfiguration, color: rowColor)

            TextField("Task title", text: $editingText)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { commitEdit() }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleField(configuration.title)
                )

            Spacer()

            Button {
                discardEdit()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleDiscardButton(configuration.title)
            )
        }
        .foregroundStyle(rowColor)
        .onChange(of: isEditingTitle) { _, newValue in
            if newValue {
                isTitleFocused = true
            }
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused && isEditingTitle {
                commitEdit()
            }
        }
    }

    // MARK: - Inline Edit Helpers

    private func beginEditing() {
        guard !isEditingTitle else { return }
        editingText = configuration.title
        isEditingTitle = true
    }

    private func commitEdit() {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditingTitle = false
        isTitleFocused = false
        guard !trimmed.isEmpty, trimmed != configuration.title else { return }
        onTitleCommit?(trimmed)
    }

    private func discardEdit() {
        isEditingTitle = false
        isTitleFocused = false
        editingText = configuration.title
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
            onDelete: {},
            onTitleCommit: { print("Committed: \($0)") }
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
                onMigrate: {},
                onTitleCommit: { print("Committed: \($0)") }
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
