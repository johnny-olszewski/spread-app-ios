import SwiftUI
import JohnnyOFoundationUI

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
    private let onEdit: (() -> Void)?
    private let onDelete: (() -> Void)?
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
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: (@MainActor (String) async -> Void)? = nil,
        inlineActionConfiguration: EntryRowInlineActionConfiguration? = nil,
        isInlineActive: Bool = false,
        onBeginInlineEditing: (() -> Void)? = nil,
        onEndInlineEditing: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.iconConfiguration = iconConfiguration
        self.onComplete = onComplete
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = onTitleCommit
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
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onTitleCommit: (@MainActor (String) async -> Void)? = nil,
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
            contextualLabel: contextualLabel,
            taskBodyPreview: task.body?.trimmingCharacters(in: .whitespacesAndNewlines),
            taskPriority: task.priority,
            tagChips: task.tags.sorted { $0.name < $1.name }.map { tag in (title: tag.name, color: tag.chipColor) }
        )
        self.iconConfiguration = StatusIconConfiguration(
            entryType: .task,
            taskStatus: task.status
        )
        self.onComplete = onComplete
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = onTitleCommit
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
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = nil
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
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onTitleCommit = nil
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
            HStack(spacing: 0) {
                rowMainContent
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
        .accessibilityLabel(configuration.accessibilityLabel)
        .accessibilityValue(configuration.accessibilityValue ?? "")
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
                    .multilineTextAlignment(.leading)
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

            if !configuration.tagChips.isEmpty {
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    ForEach(configuration.tagChips, id: \.title) { chip in
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
                if let subtitle = configuration.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                taskMetadataArea
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            if configuration.hasStrikethrough {
                Rectangle()
                    .fill(rowColor.opacity(0.9))
                    .frame(height: 1.2)
                    .padding(.trailing, -4)
                    .offset(y: 1)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var taskMetadataArea: some View {
        if configuration.hasTaskMetadata {
            VStack(alignment: .leading, spacing: 2) {
                if configuration.taskPriority != .none || configuration.taskDueDateLabel != nil {
                    HStack(spacing: 6) {
                        if let badgeTitle = configuration.taskPriority.badgeTitle {
                            Text(badgeTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(configuration.taskPriority.badgeColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(configuration.taskPriority.badgeColor.opacity(0.35), lineWidth: 1)
                                }
                        }

                        if let dueDateLabel = configuration.taskDueDateLabel {
                            Text(dueDateLabel)
                                .font(.caption)
                                .foregroundStyle(
                                    configuration.isTaskDueDateHighlighted ? Color.orange : Color.secondary
                                )
                        }
                    }
                }

                if let bodyPreview = configuration.taskBodyPreview {
                    Text(bodyPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        if let iconColor = configuration.iconColor {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(iconColor)
                .frame(width: 4, height: 18)
                .frame(width: 24, height: 24)
        } else if let inlineTaskStatus,
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
        if configuration.showsMigrationBadge, let destination = configuration.migrationDestination {
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
                        .font(.system(size: SpreadTheme.IconSize.medium))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Edit task")
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton(configuration.title)
                )
                .accessibilityElement(children: .ignore)

                if let inlineActionConfiguration {
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

                        if !inlineActionConfiguration.migrationOptions.isEmpty {
                            Divider()
                        }

                        Button {
                            Task { @MainActor in
                                await openEditSheetFromInlineActions()
                            }
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
                        Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu(configuration.title)
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
        // For tasks, use inlineTaskStatus (the immediate UI state) rather than
        // configuration (which lags behind async persistence updates) so that
        // icon and text color update the moment the user taps the status toggle.
        if let inlineStatus = inlineTaskStatus {
            switch inlineStatus {
            case .open:                       return .primary
            case .complete, .migrated, .cancelled: return .secondary
            }
        }
        if configuration.isGreyedOut || configuration.hasStrikethrough {
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
            onEdit: {},
            onDelete: {},
            onTitleCommit: { _ in }
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
                onTitleCommit: { _ in }
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
                note: DataModel.Note(title: "Active note", status: .active)
            )
            EntryRowView(
                note: DataModel.Note(title: "Migrated note (greyed)", status: .migrated),
                migrationDestination: "Next Year"
            )
        }
    }
}

// MARK: - Entry List Row

/// Dispatches an `any Entry` to the correct `EntryRowView` variant, wired to an `EntryListViewModel`.
///
/// Use this instead of a manual `switch entry.entryType` at each call site.
struct EntryListRowView: View {

    let entry: any Entry
    @Bindable var viewModel: EntryListViewModel
    let contextualLabel: String?

    var body: some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                taskRow(task)
            }
        case .note:
            if let note = entry as? DataModel.Note {
                noteRow(note)
            }
        case .event:
            if let event = entry as? DataModel.Event, let calEvent = event.calendarEvent {
                calendarEventRow(event: event, calendarEvent: calEvent)
            }
        }
    }

    private func calendarEventRow(event: DataModel.Event, calendarEvent: CalendarEvent) -> some View {
        let subtitle: String
        if calendarEvent.isAllDay {
            subtitle = "All Day · \(calendarEvent.calendarTitle)"
        } else {
            let formatter = DateFormatter()
            formatter.calendar = viewModel.calendar
            formatter.timeZone = viewModel.calendar.timeZone
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let start = formatter.string(from: calendarEvent.startDate)
            let end = formatter.string(from: calendarEvent.endDate)
            subtitle = "\(start)–\(end) · \(calendarEvent.calendarTitle)"
        }
        return EntryRowView(
            configuration: EntryRowConfiguration(
                entryType: .event,
                title: calendarEvent.title,
                isEventPast: calendarEvent.endDate < viewModel.today,
                iconColor: calendarEvent.calendarColor,
                subtitle: subtitle
            ),
            iconConfiguration: StatusIconConfiguration(entryType: .event)
        )
    }

    private func taskRow(_ task: DataModel.Task) -> some View {
        let rowStatus = viewModel.rowStatus(for: task)
        return EntryRowView(
            configuration: EntryRowConfiguration(
                entryType: .task,
                taskStatus: rowStatus,
                title: task.title,
                migrationDestination: rowStatus == .migrated
                    ? viewModel.spread.flatMap { viewModel.destinationFormatter.destination(for: task, from: $0) }
                    : nil,
                contextualLabel: contextualLabel,
                taskBodyPreview: task.bodyPreview,
                taskPriority: task.priority,
                taskDueDateLabel: task.dueDateLabel(calendar: viewModel.calendar),
                isTaskDueDateHighlighted: task.isDueDateHighlighted(today: viewModel.today, calendar: viewModel.calendar),
                tagChips: task.tags.sorted { $0.name < $1.name }.map { tag in (title: tag.name, color: tag.chipColor) }
            ),
            iconConfiguration: StatusIconConfiguration(entryType: .task, taskStatus: rowStatus),
            onComplete: rowStatus == .open ? { viewModel.onComplete?(task) } : nil,
            onEdit: {
                viewModel.dismissActiveInlineEditing()
                viewModel.onEdit?(task)
            },
            onDelete: { viewModel.onDelete?(task) },
            onTitleCommit: { @MainActor newTitle in
                await viewModel.onTitleCommit?(task, newTitle)
            },
            inlineActionConfiguration: rowStatus == .open ? viewModel.inlineActionConfiguration(for: task) : nil,
            isInlineActive: viewModel.activeInlineTaskID == task.id,
            onBeginInlineEditing: { viewModel.activeInlineTaskID = task.id },
            onEndInlineEditing: {
                if viewModel.activeInlineTaskID == task.id {
                    viewModel.activeInlineTaskID = nil
                }
            }
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.taskRow(task.title))
    }

    private func noteRow(_ note: DataModel.Note) -> some View {
        EntryRowView(
            note: note,
            migrationDestination: viewModel.spread.flatMap { viewModel.destinationFormatter.destination(for: note, from: $0) },
            contextualLabel: contextualLabel,
            onEdit: {
                viewModel.dismissActiveInlineEditing()
                viewModel.onEdit?(note)
            },
            onDelete: { viewModel.onDelete?(note) }
        )
    }
}

// MARK: - Add Task Button

/// Tappable "Add Task" affordance that presents a native alert for quick task entry.
///
/// Self-contained: owns its own alert-presentation state and calls `onAddTask` directly.
/// No shared ViewModel state needed for creation flow.
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
