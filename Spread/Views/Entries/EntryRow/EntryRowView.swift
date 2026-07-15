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

    /// Measured height of the row's text column (title row + optional subtitle), captured via
    /// `ContentColumnHeightKey` so the scheduled-time block can be capped to it and never grow
    /// the row, regardless of Dynamic Type size or how many lines the title wraps to.
    @State private var contentColumnHeight: CGFloat?

    // MARK: - Initialisation

    init(entry: any Entry, configuration: Configuration) {
        self.entry = entry
        self.configuration = configuration
        _editingText = State(initialValue: entry.title)
    }

    // MARK: - Computed

    /// Chips derived from the configuration's `getChips` closure, or empty if not provided.
    private var chips: [any LabelChipRepresentable] {
        configuration.getChips?(entry) ?? []
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

    /// Read-only rows (e.g. the overdue card) disable inline title editing and the context
    /// menu, routing all non-status-icon taps to `configuration.onRowTap` instead.
    private var isReadOnly: Bool {
        configuration.onRowTap != nil
    }

    // MARK: - Body

    var body: some View {

        VStack(alignment: .leading, spacing: 2) {

            HStack {

                TextField("", text: $editingText, selection: $titleSelection)
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(entry.status.iconColor)
                    .textFieldStyle(.plain)
                    .strikethrough(configuration.hasStrikethrough?(entry) ?? false, color: .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .disabled(entry.status.inlineChangesAreLocked || isReadOnly)
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { commitTitleEdit() }
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadContent.taskTitleField(entry.title)
                    )
                    .toolbar {
                        if isTitleFocused {
                            ToolbarItemGroup(placement: .keyboard) {
                                HStack(spacing: 8) {
                                    menuButtons(labelStyle: .iconOnly)
                                }
                                .padding(.horizontal, 8)
                                Spacer()
                            }
                        }
                    }

                ForEach(chips.indices, id: \.self) { i in
                    LabelChip(chips[i])
                }

                if configuration.showsPriorityIcon?(entry) == true,
                   let icon = entry.displayPriority.icon,
                   let color = entry.displayPriority.iconColor {
                    icon.sized(SpreadTheme.IconSize.small)
                        .iconTint(color)
                }
            }
            if let subtitle = configuration.subtitle?(entry) {
                Text(subtitle)
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ContentColumnHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(ContentColumnHeightKey.self) { height in
            contentColumnHeight = height
        }
        .safeAreaInset(edge: .leading) {
            HStack(spacing: SpreadTheme.Spacing.small) {
                statusButton
                if let scheduledStart = entry.scheduledStart {
                    scheduledTimeBlock(start: scheduledStart, end: entry.scheduledEnd)
                }
            }
        }
        .safeAreaInset(edge: .trailing) {
            if $isTitleFocused.wrappedValue {
                editEntryButton(.iconOnly)
            }
        }
        .contentShape(Rectangle())
        .modifier(ReadOnlyRowInteractionModifier(
            isReadOnly: isReadOnly,
            onRowTap: { configuration.onRowTap?(entry) },
            contextMenuContent: { menuButtons(labelStyle: .titleAndIcon) }
        ))
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
                bseeShapeConfig: .init(color: entry.resolvedIconColor, iconSize: nil),
                overlay: entry.status.overlayShape,
                overlayConfig: .init(color: entry.resolvedIconColor, iconSize: nil),
                iconOverride: entry.status.iconOverride
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .allowsHitTesting(configuration.onStatusIconTap != nil)
    }

    /// The scheduled-time column shown between the status icon and the title/details column
    /// when `entry.scheduledStart` is non-nil. Stacks start above end (end only for timed
    /// events); tasks show a single time. Capped to `contentColumnHeight` — the measured height
    /// of the row's text column (see `ContentColumnHeightKey`) — so a two-line time stack can
    /// never grow the row beyond what an untimed row already occupies.
    @ViewBuilder
    private func scheduledTimeBlock(start: Date, end: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(start.formatted(date: .omitted, time: .shortened))
            if let end {
                Text(end.formatted(date: .omitted, time: .shortened))
            }
        }
        .font(SpreadTheme.Typography.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(height: contentColumnHeight, alignment: .center)
        .clipped()
    }

    @ViewBuilder
    private func editEntryButton(_ labelStyle: some LabelStyle = TitleAndIconLabelStyle()) -> some View {

        if let onEdit = self.onEdit {
            Button {
                onEdit(entry)
            } label: {
                Label {
                    Text("Edit")
                } icon: {
                    SpreadTheme.Icon.editCompose.sized(SpreadTheme.IconSize.medium)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .transition(.slide)
            .labelStyle(labelStyle)
        }
    }

    @ViewBuilder
    private func menuButtons(labelStyle: some LabelStyle) -> some View {
        ForEach(configuration.actions) { action in
            action.menuLabel(
                labelStyle: labelStyle,
                entry: entry,
                editEntryButton: { AnyView(editEntryButton(labelStyle)) },
                onConfirmChanges: { completion in
                    isConfirmingChanges = true
                    Task { @MainActor in
                        await confirmChanges(completion)
                    }
                },
                showAlert: configuration.showAlert
            )
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
            isConfirmingChanges = false
            await completion()
            return
        }

        let alert = SpreadsCoordinator.AlertDestination.alert(
            AlertModel.discardChanges(
                onSave: {
                    isConfirmingChanges = false
                    commitTitleEdit()
                    await completion()
                },
                onDiscard: {
                    isConfirmingChanges = false
                    await completion()
                }
            )
        )

        configuration.showAlert?(alert)
        isConfirmingChanges = false
    }
}

// MARK: - Read-Only Row Interaction

/// Switches a row between its normal long-press context menu and a read-only tap-to-navigate
/// mode, depending on `isReadOnly`. Kept as a separate modifier (rather than inline `if`/`else`
/// in `EntryRowView.body`) so the two interaction modes don't need to share one expression's type.
private struct ReadOnlyRowInteractionModifier<ContextMenuContent: View>: ViewModifier {
    let isReadOnly: Bool
    let onRowTap: () -> Void
    @ViewBuilder let contextMenuContent: () -> ContextMenuContent

    func body(content: Content) -> some View {
        if isReadOnly {
            content.onTapGesture(perform: onRowTap)
        } else {
            content.contextMenu(menuItems: contextMenuContent)
        }
    }
}

// MARK: - Content Column Height Measurement

/// Reports the rendered height of `EntryRowView`'s text column (title row + optional subtitle)
/// so the scheduled-time leading column can be capped to it via `contentColumnHeight`.
private struct ContentColumnHeightKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
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

#Preview("Task - Scheduled Time") {
    let task = DataModel.Task(
        title: "Call the dentist",
        scheduledTime: .getDate(calendar: .current, year: 2026, month: 7, day: 10)?
            .addingTimeInterval(15 * 3600),
        status: .open
    )
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in false },
        hasStrikethrough: { _ in false },
        onStatusIconTap: { _ in },
        onTitleCommit: { _, _ in }
    )
    List { EntryRowView(entry: task, configuration: config) }
}

#Preview("Event - Timed Range") {
    let start = Date.getDate(calendar: .current, year: 2026, month: 7, day: 10)?.addingTimeInterval(9.5 * 3600) ?? .now
    let end = start.addingTimeInterval(3600)
    let event = DataModel.Event(
        title: "Design review",
        timing: .timed,
        startDate: start,
        endDate: end,
        startTime: start,
        endTime: end
    )
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in false }
    )
    List { EntryRowView(entry: event, configuration: config) }
}

#Preview("Event - Calendar Tint (Upcoming)") {
    let start = Date.getDate(calendar: .current, year: 2026, month: 7, day: 10)?.addingTimeInterval(9.5 * 3600) ?? .now
    let end = start.addingTimeInterval(3600)
    let calendarEvent = CalendarEvent(
        id: "preview-upcoming",
        title: "Design review",
        startDate: start,
        endDate: end,
        isAllDay: false,
        calendarTitle: "Work",
        calendarColor: .purple
    )
    let event = DataModel.Event(calendarEvent: calendarEvent, asOf: start.addingTimeInterval(-3600), calendar: .current)
    let config = EntryRowView.Configuration()
    List { EntryRowView(entry: event, configuration: config) }
}

#Preview("Event - Calendar Tint (Passed)") {
    let start = Date.getDate(calendar: .current, year: 2026, month: 7, day: 10)?.addingTimeInterval(9.5 * 3600) ?? .now
    let end = start.addingTimeInterval(3600)
    let calendarEvent = CalendarEvent(
        id: "preview-passed",
        title: "Design review",
        startDate: start,
        endDate: end,
        isAllDay: false,
        calendarTitle: "Work",
        calendarColor: .purple
    )
    let event = DataModel.Event(calendarEvent: calendarEvent, asOf: end.addingTimeInterval(3600), calendar: .current)
    let config = EntryRowView.Configuration()
    List { EntryRowView(entry: event, configuration: config) }
}

#Preview("Task - No Time") {
    let task = DataModel.Task(title: "Water the plants", status: .open)
    let config = EntryRowView.Configuration(
        isGreyedOut: { _ in false },
        hasStrikethrough: { _ in false },
        onStatusIconTap: { _ in },
        onTitleCommit: { _, _ in }
    )
    List { EntryRowView(entry: task, configuration: config) }
}
