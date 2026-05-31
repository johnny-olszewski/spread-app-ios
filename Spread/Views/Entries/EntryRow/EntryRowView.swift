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
    @State private var isConfirmingChanges: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    // MARK: - Initialisation
    
    init(entry: any Entry, configuration: Configuration) {
        self.entry = entry
        self.configuration = configuration
        _editingText = State(initialValue: entry.title)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        return "\(entry.status.displayName)-\(entry.entryType.displayName)-\(entry.title)"
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
    
    // MARK: - Convenience
    
    private var onEdit: ((any Entry) -> Void)? {
        
        for action in configuration.actions {
            if case .openEdit(let onEdit) = action {
                return onEdit
            }
        }
        
        return nil
    }
    
    /// Inline editing is supported when the configuration provides a title-commit handler
    /// and the effective status is open. The call site controls both signals via configuration
    /// closures — no entry-type checks here.
    private var supportsInlineEditing: Bool {
        return configuration.onTitleCommit != nil
    }
    
    // MARK: - Body
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 2) {
            
            TextField("", text: $editingText, selection: $titleSelection)
                .font(.body)
                .foregroundStyle(entry.status.iconColor)
                .textFieldStyle(.plain)
                .strikethrough(configuration.hasStrikethrough?(entry) ?? false, color: .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .disabled(entry.status.inlineChangesAreLocked)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { commitTitleEdit() }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleField(entry.title)
                )
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        menuButtons(labelVisibility: .hidden)
                    }
                }
            
            if let subtitle = configuration.subtitle?(entry) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .safeAreaInset(edge: .leading) {
            statusButton
        }
        .safeAreaInset(edge: .trailing) {
            if $isTitleFocused.wrappedValue {
                editEntryButton(.hidden)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            menuButtons(labelVisibility: .visible)
        }
        
        //        }
        .onChange(of: isTitleFocused) { _, isFocused in
            if isFocused {
                editingText = entry.title
                titleSelection = TextSelection(insertionPoint: editingText.endIndex)
            } else {
                if isConfirmingChanges == false {
                    editingText = entry.title
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
    }
    
    // MARK: - Subviews
    
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
    private var statusButton: some View {
        Button {
            if isTitleFocused {
                /// if title was being edited when status button was hit, lose focus, save the title, then update the status
                isTitleFocused = false
                commitTitleEdit()
            }
            configuration.onStatusIconTap?(entry)
        } label: {
            EntryStatusIcon(
                baseShape: entry.baseShape,
                bseeShapeConfig: .init(color: entry.status.iconColor, iconSize: nil),
                overlay: entry.status.overlayShape,
                overlayConfig: .init(color: entry.status.iconColor, iconSize: nil)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .allowsHitTesting(configuration.onStatusIconTap != nil)
    }
    
    @ViewBuilder
    private func editEntryButton(_ labelVisibility: Visibility = .visible) -> some View {
        
        if let onEdit = self.onEdit {
            Button {
                onEdit(entry)
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .transition(.slide)
            .labelsVisibility(labelVisibility)
        }
    }
    
    @ViewBuilder
    private func menuButtons(labelVisibility: Visibility) -> some View {
        ForEach(configuration.actions) { action in
            toolbarItem(for: action, labelVisibility: labelVisibility)
        }
    }
    
    @ViewBuilder
    private func toolbarItem(for action: Configuration.Action, labelVisibility: Visibility) -> some View {
        switch action {
        case .openEdit(_):
            editEntryButton(labelVisibility)
        case .migrate(let migrationOptions, let onMigrationSelected):
            let options = migrationOptions(entry)
            if !options.isEmpty {
                Menu {
                    ForEach(options) { option in
                        Button {
                            isConfirmingChanges = true
                            
                            guard configuration.showAlert != nil else {
                                return
                            }
                            
                            Task { @MainActor in
                                await confirmChanges { await onMigrationSelected(entry, option) }
                            }
                        } label: {
                            Label(option.label, systemImage: action.systemImageName)
                        }
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationOption(
                                entry.title,
                                option: option.kind.rawValue
                            )
                        )
                    }
                } label: {
                    Label("Migrate", systemImage: action.systemImageName)
                        .font(.system(size: SpreadTheme.IconSize.medium))
                        .labelsVisibility(labelVisibility)
                }
                .accessibilityLabel("Migrate")
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu(entry.title)
                )
            }
        case .delete(let deleteEntry):
            Button {
                let alert = SpreadsCoordinator.AlertDestination.deleteEntryConfirmation(confirmAction: {
                    await deleteEntry(entry)
                })

                configuration.showAlert?(alert)
            } label: {
                Label("Delete", systemImage: action.systemImageName)
            }
        }
    }
    
    // MARK: - Inline Edit Helpers
    
    private func commitTitleEdit() {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        isTitleFocused = false
        titleSelection = nil
        
        guard !trimmed.isEmpty, trimmed != entry.title else { return }
        
        Task { @MainActor in
            await configuration.onTitleCommit?(entry, trimmed)
        }
    }
    
    private func confirmChanges(_ completion: @escaping @MainActor () async -> Void) async {
    
        let trimmedTitle = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasChanges = !trimmedTitle.isEmpty && trimmedTitle != entry.title

        titleSelection = nil
        isTitleFocused = false

        guard hasChanges else {
            await completion()
            return
        }

        let alert = SpreadsCoordinator.AlertDestination.discardChanges {
            commitTitleEdit()
            await completion()
        } onDiscard: {
            await completion()
        }

        configuration.showAlert?(alert)
    }
}

// MARK: - Previews

#Preview("Task - Open") {
    var task = DataModel.Task(title: "Buy groceries", status: .open)
    
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in false },
        hasStrikethrough: { _ in false },
        onStatusIconTap: { _ in },
        onTitleCommit: { _, _ in }
    )
    List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Task - Complete") {
    let task = DataModel.Task(title: "File taxes", status: .complete)
    let config = EntryRowView.Configuration(
        isGreyedOut: { entry in entry.entryType == .task && (entry.status == .complete || entry.status == .migrated || entry.status == .cancelled) },
        hasStrikethrough: { _ in false },
    )
    List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Task - Cancelled") {
    let task = DataModel.Task(title: "Buy a boat", status: .cancelled)
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in true },
        hasStrikethrough: { _ in true },
    )
    List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Note - Active") {
    let note = DataModel.Note(title: "Project ideas", status: .active)
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in false }
    )
    return List { EntryRowView(entry: note, configuration: config) }
}
