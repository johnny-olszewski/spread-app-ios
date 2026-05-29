import SwiftUI
import JohnnyOFoundationUI

/// A row component for displaying an entry with type symbol, title, and actions.
///
/// Receives a type-level `EntryRowView.Configuration` from the caller and an `Entry` to render.
/// All type-specific logic lives in configuration closures; the view has no type knowledge.
struct EntryRowView: View {

    // MARK: - Properties

    let entry: any Entry
    let configuration: Configuration

    // MARK: - Inline edit state (view-owned)

    @State private var editingText: String
    @State private var titleSelection: TextSelection?
    @State private var hasAcquiredTitleFocus: Bool = false
    @State private var isInlineActive: Bool = false
    @FocusState private var isTitleFocused: Bool

    // MARK: - Initialisation

    init(entry: any Entry, configuration: Configuration) {
        self.entry = entry
        self.configuration = configuration
        _editingText = State(initialValue: entry.title)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                EntryStatusButton(status: entry.status, entryType: entry.entryType, onTap: rowIconOnTap)

                VStack(alignment: .leading, spacing: 2) {
                    
                    // title and chips
                    topRow
                    
                    if let subtitle = configuration.subtitle?(entry) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
    //                taskMetadataArea
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { handlePrimaryTap() }

        }
        .foregroundStyle(rowColor)
        .contextMenu { contextMenuActions }
        .onChange(of: isTitleFocused) { _, focused in
            if focused {
                if isInlineActive && !hasAcquiredTitleFocus {
                    titleSelection = endOfTextCursor(for: editingText)
                }
                hasAcquiredTitleFocus = true
            } else if isInlineActive && hasAcquiredTitleFocus {
                commitEdit()
            }
        }
        .onChange(of: entry.title) { _, newTitle in
            guard !isInlineActive else { return }
            editingText = newTitle
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
    }

    // MARK: - Subviews
    
    private var rowIconOnTap: (() -> Void)? {
        guard entry.entryType == .task, configuration.onComplete != nil else { return nil }
        let effectiveStatus = configuration.effectiveTaskStatus?(entry) ?? entry.status
        guard effectiveStatus.canToggleCompletionInTaskSheet else { return nil }
        return { handleIconTap() }
    }

    @ViewBuilder
    private var topRow: some View {
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
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        ForEach(configuration.actions) { action in
                            toolbarItem(for: action)
                        }
                    }
                }

            if !entry.displayTagChips.isEmpty && !isInlineActive {
                HStack(spacing: 4) {
                    ForEach(entry.displayTagChips, id: \.title) { chip in
                        LabelChip(title: chip.title, color: chip.color)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

//    @ViewBuilder
//    private var taskMetadataArea: some View {
//        let priority = entry.displayPriority
//        let dueLabel = configuration.dueDateLabel?(entry)
//        let bodyPreview = entry.displayBodyPreview
//        if priority != .none || dueLabel != nil || bodyPreview != nil {
//            VStack(alignment: .leading, spacing: 2) {
//                if priority != .none || dueLabel != nil {
//                    HStack(spacing: 6) {
//                        if let badgeTitle = priority.badgeTitle {
//                            Text(badgeTitle)
//                                .font(.caption2.weight(.semibold))
//                                .foregroundStyle(priority.badgeColor)
//                                .padding(.horizontal, 5)
//                                .padding(.vertical, 2)
//                                .overlay {
//                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
//                                        .stroke(priority.badgeColor.opacity(0.35), lineWidth: 1)
//                                }
//                        }
//                        if let dueLabel {
//                            Text(dueLabel)
//                                .font(.caption)
//                                .foregroundStyle(
//                                    (configuration.isDueDateHighlighted?(entry) ?? false) ? Color.orange : Color.secondary
//                                )
//                        }
//                    }
//                }
//                if let preview = bodyPreview {
//                    Text(preview)
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                        .lineLimit(1)
//                }
//            }
//        }
//    }

    @ViewBuilder
    private func toolbarItem(for action: Configuration.Action) -> some View {
        switch action {
        case .edit(let onTap):
            Button {
                Task { @MainActor in await performAction { onTap(entry) } }
            } label: {
                Image(systemName: action.systemImageName)
                    .font(.system(size: SpreadTheme.IconSize.medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Edit")
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton(entry.title)
            )
        case .migrate(let migrationOptions, let onMigrationSelected):
            let options = migrationOptions(entry)
            if !options.isEmpty {
                Menu {
                    ForEach(options) { option in
                        Button {
                            Task { @MainActor in
                                await performAction { await onMigrationSelected(entry, option) }
                            }
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
                } label: {
                    Image(systemName: action.systemImageName)
                        .font(.system(size: SpreadTheme.IconSize.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Migrate")
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu(entry.title)
                )
            }
        }
    }

    // MARK: - Inline Edit Helpers

    private func beginEditing() {
        guard supportsInlineEditing, !isInlineActive else { return }
        editingText = entry.title
        titleSelection = endOfTextCursor(for: editingText)
        hasAcquiredTitleFocus = false
        withAnimation(.easeInOut(duration: 0.18)) { isInlineActive = true }
        isTitleFocused = true
    }

    private func commitEdit() {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.18)) { isInlineActive = false }
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

    private func handleIconTap() {
        if isInlineActive { commitEdit() }
        configuration.onComplete?(entry)
    }

    /// Inline editing is supported when the configuration provides a title-commit handler
    /// and the effective status is open. The call site controls both signals via configuration
    /// closures — no entry-type checks here.
    private var supportsInlineEditing: Bool {
        guard configuration.onTitleCommit != nil else { return false }
        let status = configuration.effectiveTaskStatus?(entry) ?? entry.status
        return status == .open
    }

    private func performAction(_ action: @escaping @MainActor () async -> Void) async {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChanges = !trimmed.isEmpty && trimmed != entry.title

        // Deactivate inline mode before dismissing focus so the onChange observer
        // sees isInlineActive == false and skips the auto-commit via commitEdit().
        isInlineActive = false
        titleSelection = nil
        hasAcquiredTitleFocus = false
        isTitleFocused = false

        if hasChanges, let showAlert = configuration.showDiscardChangesAlert {
            let entry = self.entry
            let onTitleCommit = configuration.onTitleCommit
            showAlert(
                {
                    await onTitleCommit?(entry, trimmed)
                    await action()
                },
                {
                    await action()
                }
            )
        } else {
            await Task.yield()
            await action()
        }
    }

    private func endOfTextCursor(for text: String) -> TextSelection {
        TextSelection(insertionPoint: text.endIndex)
    }

    // MARK: - Styling

    private var rowColor: Color {
        let greyed = configuration.isGreyedOut?(entry) ?? false
        let strikethrough = configuration.hasStrikethrough?(entry) ?? false
        return (greyed || strikethrough) ? .secondary : .primary
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
        let effectiveStatus: EntryStatus? = switch entry.entryType {
        case .task: configuration.effectiveTaskStatus?(entry) ?? entry.status
        case .note: entry.status
        case .event: nil
        }
        if let status = effectiveStatus {
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

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuActions: some View {
        if let onEdit = configuration.onEdit {
            Button { onEdit(entry) } label: { Label("Edit", systemImage: "pencil") }
        }
        if configuration.onComplete != nil, entry.entryType == .task, entry.status == .open {
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
        effectiveTaskStatus: { $0.entryType == .task ? $0.status : nil },
        isGreyedOut: { _ in false },
        hasStrikethrough: { _ in false },
        onComplete: { _ in },
        onEdit: { _ in },
        onDelete: { _ in },
        onTitleCommit: { _, _ in }
    )
    List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Task - Complete") {
    let task = DataModel.Task(title: "File taxes", status: .complete)
    let config = EntryRowView.Configuration(
        effectiveTaskStatus: { $0.entryType == .task ? $0.status : nil },
        isGreyedOut: { entry in entry.entryType == .task && (entry.status == .complete || entry.status == .migrated || entry.status == .cancelled) },
        hasStrikethrough: { _ in false },
        onEdit: { _ in },
        onDelete: { _ in }
    )
    List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Task - Cancelled") {
    let task = DataModel.Task(title: "Buy a boat", status: .cancelled)
    let config = EntryRowView.Configuration(
        effectiveTaskStatus: { $0.entryType == .task ? $0.status : nil },
        isGreyedOut: { _ in true },
        hasStrikethrough: { _ in true }
    )
    List { EntryRowView(entry: task, configuration: config) }
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
