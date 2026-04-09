import SwiftUI

struct EntryRowTrailingAction {
    let systemImage: String
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct EntryRowInlineActionConfiguration {
    let migrationOptions: [EntryRowInlineMigrationOption]
    let onEditSheet: () -> Void
    let onMigrationSelected: (EntryRowInlineMigrationOption) async -> Void
}

/// A row component for displaying an entry with type symbol, title, and actions.
///
/// Interaction model:
/// - Tapping an open task row activates inline title editing.
/// - Tapping a completed/cancelled task row opens the full edit sheet via `onEdit`.
/// - Long-pressing the row shows a context menu with Edit, Complete, Migrate, Delete.
struct EntryRowView: View {

    // MARK: - Properties

    private let configuration: EntryRowConfiguration
    private let iconConfiguration: StatusIconConfiguration

    private let onComplete: (() -> Void)?
    private let onMigrate: (() -> Void)?
    private let onEdit: (() -> Void)?
    private let onDelete: (() -> Void)?
    private let trailingAction: EntryRowTrailingAction?
    private let inlineActionConfiguration: EntryRowInlineActionConfiguration?
    private let isInlineActive: Bool
    private let onBeginInlineEditing: (() -> Void)?
    private let onEndInlineEditing: (() -> Void)?

    /// Callback when the user commits an inline title edit (open tasks only).
    private let onTitleCommit: (@MainActor (String) async -> Void)?

    // MARK: - Inline edit state

    @State private var editingText: String
    @State private var titleSelection: TextSelection?
    @State private var inlineTaskStatus: DataModel.Task.Status?
    @State private var hasAcquiredTitleFocus: Bool = false
    @State private var isPerformingInlineAction: Bool = false
    @FocusState private var isTitleFocused: Bool

    // MARK: - Initialization

    init(
        configuration: EntryRowConfiguration,
        iconConfiguration: StatusIconConfiguration,
        onComplete: (() -> Void)? = nil,
        onMigrate: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: (@MainActor (String) async -> Void)? = nil,
        trailingAction: EntryRowTrailingAction? = nil,
        inlineActionConfiguration: EntryRowInlineActionConfiguration? = nil,
        isInlineActive: Bool = false,
        onBeginInlineEditing: (() -> Void)? = nil,
        onEndInlineEditing: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.iconConfiguration = iconConfiguration
        self.onComplete = onComplete
        self.onMigrate = onMigrate
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = onTitleCommit
        self.trailingAction = trailingAction
        self.inlineActionConfiguration = inlineActionConfiguration
        self.isInlineActive = isInlineActive
        self.onBeginInlineEditing = onBeginInlineEditing
        self.onEndInlineEditing = onEndInlineEditing
        _editingText = State(initialValue: configuration.title)
        _inlineTaskStatus = State(initialValue: configuration.taskStatus)
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
        onTitleCommit: (@MainActor (String) async -> Void)? = nil,
        trailingAction: EntryRowTrailingAction? = nil,
        inlineActionConfiguration: EntryRowInlineActionConfiguration? = nil,
        isInlineActive: Bool = false,
        onBeginInlineEditing: (() -> Void)? = nil,
        onEndInlineEditing: (() -> Void)? = nil
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
        self.trailingAction = trailingAction
        self.inlineActionConfiguration = inlineActionConfiguration
        self.isInlineActive = isInlineActive
        self.onBeginInlineEditing = onBeginInlineEditing
        self.onEndInlineEditing = onEndInlineEditing
        _editingText = State(initialValue: task.title)
        _inlineTaskStatus = State(initialValue: task.status)
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
        self.trailingAction = nil
        self.inlineActionConfiguration = nil
        self.isInlineActive = false
        self.onBeginInlineEditing = nil
        self.onEndInlineEditing = nil
        _editingText = State(initialValue: event.title)
        _inlineTaskStatus = State(initialValue: nil)
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
        self.trailingAction = nil
        self.inlineActionConfiguration = nil
        self.isInlineActive = false
        self.onBeginInlineEditing = nil
        self.onEndInlineEditing = nil
        _editingText = State(initialValue: note.title)
        _inlineTaskStatus = State(initialValue: nil)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                leadingAccessory

                titleArea

                Spacer()

                trailingAccessory
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handlePrimaryTap()
            }

            inlineActionRow
        }
        .foregroundStyle(rowColor)
        .contextMenu {
            contextMenuActions
        }
        .onChange(of: isInlineActive) { oldValue, newValue in
            guard oldValue != newValue else { return }
            syncInlineEditingState(isActive: newValue)
        }
        .onChange(of: isTitleFocused) { _, focused in
            if focused {
                if isInlineActive && !hasAcquiredTitleFocus {
                    titleSelection = fullTextSelection(for: editingText)
                }
                hasAcquiredTitleFocus = true
            } else if isInlineActive && hasAcquiredTitleFocus && !isPerformingInlineAction {
                commitEdit(clearParentSelection: true)
            }
        }
        .onChange(of: configuration.title) { _, newTitle in
            guard !isInlineActive else { return }
            editingText = newTitle
        }
        .onChange(of: configuration.taskStatus) { _, newStatus in
            inlineTaskStatus = newStatus
        }
        .animation(.easeInOut(duration: 0.18), value: isInlineActive)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var titleArea: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ZStack(alignment: .leading) {
                Text(configuration.title)
                    .font(.body)
                    .strikethrough(configuration.hasStrikethrough)
                    .lineLimit(2)
                    .opacity(isInlineActive ? 0 : 1)

                TextField("", text: $editingText, selection: $titleSelection)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { commitEdit(clearParentSelection: true) }
                    .allowsHitTesting(isInlineActive)
                    .opacity(isInlineActive ? 1 : 0.01)
                    .accessibilityHidden(!isInlineActive)
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleField(configuration.title)
                    )
            }

            if let contextualLabel = configuration.contextualLabel {
                contextualLabelView(contextualLabel)
            }
        }
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if let inlineTaskStatus,
           configuration.entryType == .task {
            TaskStatusToggleButton(
                status: Binding(
                    get: { inlineTaskStatus },
                    set: { newStatus in
                        self.inlineTaskStatus = newStatus
                        guard newStatus != configuration.taskStatus else { return }
                        onComplete?()
                    }
                ),
                accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskStatusToggle(
                    configuration.title
                ),
                size: .caption,
                color: rowColor
            )
        } else {
            StatusIcon(configuration: iconConfiguration, color: rowColor)
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if let trailingAction {
            Button(action: trailingAction.action) {
                Image(systemName: trailingAction.systemImage)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(trailingAction.accessibilityIdentifier)
        } else if configuration.showsMigrationBadge, let destination = configuration.migrationDestination {
            migrationBadge(destination: destination)
        }
    }

    @ViewBuilder
    private var inlineActionRow: some View {
        if supportsInlineEditing && isInlineActive {
            HStack(spacing: 16) {
                Button {
                    Task { @MainActor in
                        await openEditSheetFromInlineActions()
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit task")
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton(configuration.title)
                )
                .accessibilityElement(children: .ignore)

                if let inlineActionConfiguration,
                   !inlineActionConfiguration.migrationOptions.isEmpty {
                    Menu {
                        ForEach(inlineActionConfiguration.migrationOptions) { option in
                            Button {
                                Task { @MainActor in
                                    await performInlineMigration(option)
                                }
                            } label: {
                                Text(option.label)
                            }
                            .accessibilityIdentifier(
                                Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationOption(
                                    configuration.title,
                                    option: option.kind.rawValue
                                )
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu(configuration.title)
                    )
                    .accessibilityElement(children: .ignore)
                }

                Spacer()
            }
            .padding(.leading, 24 + SpreadTheme.Spacing.entryIconSpacing)
            .frame(height: 20)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Inline Edit Helpers

    private func beginEditing() {
        guard supportsInlineEditing, !isInlineActive else { return }
        editingText = configuration.title
        titleSelection = fullTextSelection(for: editingText)
        hasAcquiredTitleFocus = false
        onBeginInlineEditing?()
    }

    private func commitEdit(clearParentSelection: Bool) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        isTitleFocused = false
        titleSelection = nil
        hasAcquiredTitleFocus = false
        if clearParentSelection {
            onEndInlineEditing?()
        }
        guard !trimmed.isEmpty, trimmed != configuration.title else { return }
        Task { @MainActor in
            await onTitleCommit?(trimmed)
        }
    }

    private func handlePrimaryTap() {
        guard !isInlineActive else { return }

        switch primaryInteraction {
        case .inlineEdit:
            beginEditing()
        case .fullEditSheet:
            onEdit?()
        }
    }

    private var supportsInlineEditing: Bool {
        primaryInteraction == .inlineEdit
    }

    private var primaryInteraction: EntryRowPrimaryInteraction {
        EntryRowInlineEditSupport.primaryInteraction(
            entryType: configuration.entryType,
            taskStatus: configuration.taskStatus,
            canInlineEditTitle: onTitleCommit != nil
        )
    }

    private func openEditSheetFromInlineActions() async {
        isPerformingInlineAction = true
        isTitleFocused = false

        await EntryRowInlineEditSupport.performInlineAction(
            draftTitle: editingText,
            originalTitle: configuration.title,
            onCommit: { title in
                await onTitleCommit?(title)
            },
            action: {
                onEndInlineEditing?()
                await Task.yield()
                onEdit?()
            }
        )
        isPerformingInlineAction = false
    }

    private func performInlineMigration(_ option: EntryRowInlineMigrationOption) async {
        isPerformingInlineAction = true
        isTitleFocused = false

        await EntryRowInlineEditSupport.performInlineAction(
            draftTitle: editingText,
            originalTitle: configuration.title,
            onCommit: { title in
                await onTitleCommit?(title)
            },
            action: {
                onEndInlineEditing?()
                await inlineActionConfiguration?.onMigrationSelected(option)
            }
        )
        isPerformingInlineAction = false
    }

    private func discardEdit() {
        onEndInlineEditing?()
        isTitleFocused = false
        hasAcquiredTitleFocus = false
        editingText = configuration.title
        titleSelection = nil
    }

    private func syncInlineEditingState(isActive: Bool) {
        if isActive {
            editingText = configuration.title
            titleSelection = fullTextSelection(for: editingText)
            hasAcquiredTitleFocus = false
            isTitleFocused = true
        } else if hasAcquiredTitleFocus && !isPerformingInlineAction {
            commitEdit(clearParentSelection: false)
        } else {
            isTitleFocused = false
            titleSelection = nil
            hasAcquiredTitleFocus = false
            editingText = configuration.title
        }
    }

    private func fullTextSelection(for text: String) -> TextSelection {
        if text.isEmpty {
            return TextSelection(insertionPoint: text.startIndex)
        }
        return TextSelection(range: text.startIndex..<text.endIndex)
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
