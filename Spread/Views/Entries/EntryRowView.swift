import SwiftUI

/// A row component for displaying an entry with type symbol, title, and actions.
///
/// Interaction model:
/// - Tapping the title of an open task activates inline title editing.
/// - Tapping anywhere else on the row opens the full edit sheet via `onEdit`.
/// - Long-pressing the row shows a context menu with Edit, Complete, Migrate, Delete.
///
/// The outer HStack is always present so the row height never shifts when entering
/// or leaving inline editing mode.
struct EntryRowView: View {

    // MARK: - Properties

    private let configuration: EntryRowConfiguration
    private let iconConfiguration: StatusIconConfiguration

    private let onComplete: (() -> Void)?
    private let onMigrate: (() -> Void)?
    private let onEdit: (() -> Void)?
    private let onDelete: (() -> Void)?

    /// Callback when the user commits an inline title edit (open tasks only).
    private let onTitleCommit: ((String) -> Void)?

    // MARK: - Inline edit state

    @State private var isEditingTitle: Bool = false
    @State private var editingText: String = ""
    @FocusState private var isTitleFocused: Bool

    // MARK: - Initialization

    init(
        configuration: EntryRowConfiguration,
        iconConfiguration: StatusIconConfiguration,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: ((String) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.iconConfiguration = iconConfiguration
        self.onComplete = onComplete
        self.onMigrate = onMigrate
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = onTitleCommit
    }

    /// Creates an entry row view for a task.
    init(
        task: DataModel.Task,
        migrationDestination: String? = nil,
        contextualLabel: String? = nil,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: ((String) -> Void)? = nil
    ) {
        self.configuration = EntryRowConfiguration(
            entryType: .task,
            taskStatus: task.status,
            title: task.title,
            migrationDestination: migrationDestination,
            contextualLabel: contextualLabel
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
    }

    /// Creates an entry row view for an event.
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
        self.onTitleCommit = nil
    }

    /// Creates an entry row view for a note.
    init(
        note: DataModel.Note,
        migrationDestination: String? = nil,
        contextualLabel: String? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.configuration = EntryRowConfiguration(
            entryType: .note,
            noteStatus: note.status,
            title: note.title,
            migrationDestination: migrationDestination,
            contextualLabel: contextualLabel
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
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(configuration: iconConfiguration, color: rowColor)

            titleArea

            Spacer()

            trailingAccessory
        }
        .foregroundStyle(rowColor)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditingTitle else { return }
            onEdit?()
        }
        .contextMenu {
            contextMenuActions
        }
        .onChange(of: isEditingTitle) { _, editing in
            if editing { isTitleFocused = true }
        }
        .onChange(of: isTitleFocused) { _, focused in
            if !focused && isEditingTitle { commitEdit() }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var titleArea: some View {
        if isEditingTitle {
            TextField("Task title", text: $editingText)
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { commitEdit() }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleField(configuration.title)
                )
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(configuration.title)
                    .strikethrough(configuration.hasStrikethrough)
                    .lineLimit(2)
                    .onTapGesture {
                        guard configuration.entryType == .task,
                              onTitleCommit != nil,
                              configuration.taskStatus == .open else { return }
                        beginEditing()
                    }

                if let contextualLabel = configuration.contextualLabel {
                    contextualLabelView(contextualLabel)
                }
            }
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if isEditingTitle {
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
        } else if configuration.showsMigrationBadge, let destination = configuration.migrationDestination {
            migrationBadge(destination: destination)
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

    @ViewBuilder
    private func contextualLabelView(_ contextualLabel: String) -> some View {
        let label = Text(contextualLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize()

        if configuration.entryType == .task {
            label.accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadContent.taskContextLabel(configuration.title)
            )
        } else {
            label
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuActions: some View {
        if configuration.canEdit, let onEdit {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        if configuration.canComplete, let onComplete {
            Button {
                onComplete()
            } label: {
                Label("Complete", systemImage: "checkmark.circle")
            }
        }

        if configuration.canMigrate, let onMigrate {
            Button {
                onMigrate()
            } label: {
                Label("Migrate", systemImage: "arrow.right.circle")
            }
        }

        if configuration.canDelete, let onDelete {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
