import SwiftUI
import JohnnyOFoundationUI

struct EntryRowInlineActionConfiguration {
    let migrationOptions: [EntryRowInlineMigrationOption]
    let onEditSheet: () -> Void
    let onMigrationSelected: (EntryRowInlineMigrationOption) async -> Void
}

/// A row component for displaying an entry with type symbol, title, and actions.
///
/// Receives a type-level `EntryRowView.Configuration` from the caller and an `Entry` to render.
/// All type-specific logic lives in configuration closures; the view has no type knowledge.
struct EntryRowView: View {

    // MARK: - Properties

    let entry: any Entry
    let configuration: Configuration
    var contextualLabel: String?

    // MARK: - Inline edit state (view-owned)

    @State private var editingText: String
    @State private var titleSelection: TextSelection?
    @State private var inlineTaskStatus: DataModel.Task.Status?
    @State private var hasAcquiredTitleFocus: Bool = false
    @State private var isPerformingInlineAction: Bool = false
    @State private var isInlineActive: Bool = false
    @FocusState private var isTitleFocused: Bool

    // MARK: - Initialisation

    init(entry: any Entry, configuration: Configuration, contextualLabel: String? = nil) {
        self.entry = entry
        self.configuration = configuration
        self.contextualLabel = contextualLabel
        _editingText = State(initialValue: entry.title)
        _inlineTaskStatus = State(initialValue: configuration.effectiveTaskStatus?(entry) ?? entry.displayTaskStatus)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowMainContent
                .contentShape(Rectangle())
                .onTapGesture { handlePrimaryTap() }

            inlineActionRow
        }
        .foregroundStyle(rowColor)
        .contextMenu { contextMenuActions }
        .onChange(of: isTitleFocused) { _, focused in
            if focused {
                if isInlineActive && !hasAcquiredTitleFocus {
                    titleSelection = endOfTextCursor(for: editingText)
                }
                hasAcquiredTitleFocus = true
            } else if isInlineActive && hasAcquiredTitleFocus && !isPerformingInlineAction {
                commitEdit()
            }
        }
        .onChange(of: configuration.effectiveTaskStatus?(entry) ?? entry.displayTaskStatus) { _, newStatus in
            inlineTaskStatus = newStatus
        }
        .onChange(of: entry.title) { _, newTitle in
            guard !isInlineActive else { return }
            editingText = newTitle
        }
        .animation(.easeInOut(duration: 0.18), value: isInlineActive)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var titleArea: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("", text: $editingText, selection: $titleSelection)
                .font(.body)
                .textFieldStyle(.plain)
                .strikethrough(configuration.hasStrikethrough?(entry) ?? false)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { commitEdit() }
                .allowsHitTesting(isInlineActive)
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleField(entry.title)
                )

            if let label = contextualLabel {
                contextualLabelView(label)
            }

            if !entry.displayTagChips.isEmpty {
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    ForEach(entry.displayTagChips, id: \.title) { chip in
                        LabelChip(title: chip.title, color: chip.color)
                    }
                }
                .opacity(isInlineActive ? 0 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowMainContent: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            leadingAccessory
            VStack(alignment: .leading, spacing: 3) {
                titleArea
                if let sub = configuration.subtitle?(entry) {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                taskMetadataArea
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var taskMetadataArea: some View {
        let priority = entry.displayPriority
        let dueLabel = configuration.dueDateLabel?(entry)
        let bodyPreview = entry.displayBodyPreview
        if priority != .none || dueLabel != nil || bodyPreview != nil {
            VStack(alignment: .leading, spacing: 2) {
                if priority != .none || dueLabel != nil {
                    HStack(spacing: 6) {
                        if let badgeTitle = priority.badgeTitle {
                            Text(badgeTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(priority.badgeColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(priority.badgeColor.opacity(0.35), lineWidth: 1)
                                }
                        }
                        if let dueLabel {
                            Text(dueLabel)
                                .font(.caption)
                                .foregroundStyle(
                                    (configuration.isDueDateHighlighted?(entry) ?? false) ? Color.orange : Color.secondary
                                )
                        }
                    }
                }
                if let preview = bodyPreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if let iconColor = entry.iconColor {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(iconColor)
                .frame(width: 4, height: 18)
                .frame(width: 24, height: 24)
        } else if configuration.onComplete != nil, let status = inlineTaskStatus {
            TaskStatusToggleButton(
                status: Binding(
                    get: { status },
                    set: { newStatus in
                        self.inlineTaskStatus = newStatus
                        let original = configuration.effectiveTaskStatus?(entry) ?? entry.displayTaskStatus
                        guard newStatus != original else { return }
                        configuration.onComplete?(entry)
                    }
                ),
                accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskStatusToggle(entry.title),
                size: .caption,
                color: rowColor
            )
        } else {
            StatusIcon(configuration: iconConfiguration, color: rowColor)
        }
    }

    @ViewBuilder
    private var inlineActionRow: some View {
        if supportsInlineEditing && isInlineActive {
            HStack(spacing: 16) {
                Button {
                    Task { @MainActor in await openEditSheetFromInlineActions() }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: SpreadTheme.IconSize.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Edit task")
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton(entry.title)
                )
                .accessibilityElement(children: .ignore)

                if let inlineConfig = configuration.inlineActionConfiguration?(entry) {
                    Menu {
                        ForEach(inlineConfig.migrationOptions) { option in
                            Button {
                                Task { @MainActor in await performInlineMigration(option, inlineConfig: inlineConfig) }
                            } label: {
                                Text(option.label)
                            }
                            .accessibilityIdentifier(
                                Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationOption(
                                    entry.title,
                                    option: option.kind.rawValue
                                )
                            )
                        }
                        if !inlineConfig.migrationOptions.isEmpty { Divider() }
                        Button {
                            Task { @MainActor in await openEditSheetFromInlineActions() }
                        } label: {
                            Text("Custom...")
                        }
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: SpreadTheme.IconSize.medium))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .contentShape(Rectangle())
                    .accessibilityLabel("Migrate task")
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu(entry.title)
                    )
                    .accessibilityElement(children: .ignore)
                }

                Spacer()
            }
            .padding(.leading, 24 + SpreadTheme.Spacing.entryIconSpacing)
            .frame(minHeight: 44)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Inline Edit Helpers

    private func beginEditing() {
        guard supportsInlineEditing, !isInlineActive else { return }
        editingText = entry.title
        titleSelection = endOfTextCursor(for: editingText)
        hasAcquiredTitleFocus = false
        isInlineActive = true
        isTitleFocused = true
    }

    private func commitEdit() {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        isInlineActive = false
        isTitleFocused = false
        titleSelection = nil
        hasAcquiredTitleFocus = false
        guard !trimmed.isEmpty, trimmed != entry.title else { return }
        Task { @MainActor in
            await configuration.onTitleCommit?(entry, trimmed)
        }
    }

    private func handlePrimaryTap() {
        guard !isInlineActive else { return }
        if supportsInlineEditing {
            beginEditing()
        } else {
            configuration.onEdit?(entry)
        }
    }

    /// Inline editing is supported when the configuration provides a title-commit handler
    /// and the effective status is open. The call site controls both signals via configuration
    /// closures — no entry-type checks here.
    private var supportsInlineEditing: Bool {
        guard configuration.onTitleCommit != nil else { return false }
        let status = configuration.effectiveTaskStatus?(entry) ?? entry.displayTaskStatus
        return status == .open
    }

    private func openEditSheetFromInlineActions() async {
        isPerformingInlineAction = true
        isTitleFocused = false
        await EntryRowInlineEditSupport.performInlineAction(
            draftTitle: editingText,
            originalTitle: entry.title,
            onCommit: { title in await configuration.onTitleCommit?(entry, title) },
            action: {
                isInlineActive = false
                await Task.yield()
                configuration.onEdit?(entry)
            }
        )
        isPerformingInlineAction = false
    }

    private func performInlineMigration(_ option: EntryRowInlineMigrationOption, inlineConfig: EntryRowInlineActionConfiguration) async {
        isPerformingInlineAction = true
        isTitleFocused = false
        await EntryRowInlineEditSupport.performInlineAction(
            draftTitle: editingText,
            originalTitle: entry.title,
            onCommit: { title in await configuration.onTitleCommit?(entry, title) },
            action: {
                isInlineActive = false
                await inlineConfig.onMigrationSelected(option)
            }
        )
        isPerformingInlineAction = false
    }

    private func endOfTextCursor(for text: String) -> TextSelection {
        TextSelection(insertionPoint: text.endIndex)
    }

    // MARK: - Styling

    private var rowColor: Color {
        if let inlineStatus = inlineTaskStatus {
            switch inlineStatus {
            case .open: return .primary
            case .complete, .migrated, .cancelled: return .secondary
            }
        }
        let greyed = configuration.isGreyedOut?(entry) ?? false
        let strikethrough = configuration.hasStrikethrough?(entry) ?? false
        return (greyed || strikethrough) ? .secondary : .primary
    }

    private var iconConfiguration: StatusIconConfiguration {
        StatusIconConfiguration(
            entryType: entry.entryType,
            taskStatus: configuration.effectiveTaskStatus?(entry) ?? entry.displayTaskStatus,
            noteStatus: entry.displayNoteStatus,
            isEventPast: configuration.isEventPast?(entry) ?? false
        )
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let typeName: String
        switch entry.entryType {
        case .task: typeName = "Task"
        case .note: typeName = "Note"
        case .event: typeName = "Event"
        }
        var parts = [entry.title, typeName]
        if let status = (configuration.effectiveTaskStatus?(entry) ?? entry.displayTaskStatus) {
            parts.append(status.displayName)
        } else if let status = entry.displayNoteStatus {
            parts.append(status.displayName)
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityValue: String? {
        let priority = entry.displayPriority
        var parts: [String] = []
        if priority != .none, let badge = priority.badgeTitle {
            parts.append("\(badge) priority")
        }
        if let dueLabel = configuration.dueDateLabel?(entry) {
            parts.append("Due \(dueLabel)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func contextualLabelView(_ label: String) -> some View {
        let view = Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize()
        if entry.entryType == .task {
            view.accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadContent.taskContextLabel(entry.title)
            )
        } else {
            view
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuActions: some View {
        if let onEdit = configuration.onEdit {
            Button { onEdit(entry) } label: { Label("Edit", systemImage: "pencil") }
        }
        if configuration.onComplete != nil, inlineTaskStatus == .open {
            Button { configuration.onComplete?(entry) } label: { Label("Complete", systemImage: "checkmark.circle") }
        }
        if let onDelete = configuration.onDelete {
            Button(role: .destructive) { onDelete(entry) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

// MARK: - Add Task Button

/// Tappable "Add Task" affordance that presents a native alert for quick task entry.
struct AddTaskButton: View {

    let date: Date
    let period: Period
    let onAddTask: @MainActor (String, Date, Period) async throws -> Void

    @State private var isPresented = false
    @State private var title = ""

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                Text("Add Task")
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .alert("New Task", isPresented: $isPresented) {
            TextField("Task title", text: $title)
            Button("Save") {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                title = ""
                guard !trimmed.isEmpty else { return }
                Task { @MainActor in try? await onAddTask(trimmed, date, period) }
            }
            Button("Cancel", role: .cancel) { title = "" }
        }
    }
}

// MARK: - Previews

#Preview("Task - Open") {
    let task = DataModel.Task(title: "Buy groceries", status: .open)
    let config = EntryRowView.Configuration(
        effectiveTaskStatus: { $0.displayTaskStatus },
        isGreyedOut: { _ in false },
        hasStrikethrough: { _ in false },
        onComplete: { _ in },
        onEdit: { _ in },
        onDelete: { _ in },
        onTitleCommit: { _, _ in }
    )
    return List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Task - Complete") {
    let task = DataModel.Task(title: "File taxes", status: .complete)
    let config = EntryRowView.Configuration(
        effectiveTaskStatus: { $0.displayTaskStatus },
        isGreyedOut: { entry in entry.displayTaskStatus.map { $0 == .complete || $0 == .migrated || $0 == .cancelled } ?? false },
        hasStrikethrough: { _ in false },
        onEdit: { _ in },
        onDelete: { _ in }
    )
    return List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Task - Cancelled") {
    let task = DataModel.Task(title: "Buy a boat", status: .cancelled)
    let config = EntryRowView.Configuration(
        effectiveTaskStatus: { $0.displayTaskStatus },
        isGreyedOut: { _ in true },
        hasStrikethrough: { _ in true }
    )
    return List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Note - Active") {
    let note = DataModel.Note(title: "Project ideas", status: .active)
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in false },
        onEdit: { _ in },
        onDelete: { _ in }
    )
    return List { EntryRowView(entry: note, configuration: config) }
}
