import SwiftUI

/// Renders a pre-computed list of entry sections.
///
/// `EntryListView` is a pure renderer — it knows nothing about `SpreadDataModel` or
/// period-based grouping. Callers compute `[EntryListSection]` using `EntryListGrouper`
/// and configure an `EntryListViewModel` before passing it here.
///
/// Use `MultidayEntryGridView` for multiday spread grid layouts.
struct EntryListView: View {

    // MARK: - Properties

    @Bindable var viewModel: EntryListViewModel
    @Environment(\.eventKitService) private var eventKitService

    // MARK: - View-owned state

    @FocusState private var isInlineFocused: Bool

    // MARK: - Computed

    private static let rowInsets = EdgeInsets(
        top: SpreadTheme.Spacing.entryRowVertical,
        leading: 16,
        bottom: SpreadTheme.Spacing.entryRowVertical,
        trailing: 16
    )

    // MARK: - Body

    var body: some View {
        contentView
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isInlineFocused {
                        Button("Cancel") {
                            dismissInlineCreation()
                        }
                        .glassEffect(in: Capsule())

                        Spacer()

                        Button("Save") {
                            if let target = viewModel.activeInlineCreationTarget {
                                viewModel.commitInlineTask(target: target)
                            }
                        }
                        .glassEffect(in: Capsule())
                        .disabled(viewModel.inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onChange(of: isInlineFocused) { _, focused in
                if focused {
                    viewModel.hasAcquiredInlineCreationFocus = true
                    return
                }
                guard viewModel.hasAcquiredInlineCreationFocus,
                      viewModel.activeInlineCreationTarget != nil else { return }
                let trimmed = viewModel.inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    dismissInlineCreation()
                } else if let target = viewModel.activeInlineCreationTarget {
                    viewModel.commitInlineTask(target: target)
                }
            }
            .onChange(of: viewModel.activeInlineCreationTarget) { _, target in
                if target == nil {
                    isInlineFocused = false
                    return
                }
                viewModel.hasAcquiredInlineCreationFocus = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    isInlineFocused = true
                }
            }
            .alert(item: $viewModel.pendingSourceMigration) { migration in
                Alert(
                    title: Text("Migrate Task"),
                    message: Text("Move \"\(migration.task.title)\" to \(viewModel.sourceMigrationDestinationTitle(for: migration.destination))?"),
                    primaryButton: .default(Text("Migrate")) {
                        viewModel.migrationConfiguration?.onSourceMigrationConfirmed(migration.task, migration.destination)
                    },
                    secondaryButton: .cancel()
                )
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if viewModel.hasAnyEntries || viewModel.onAddTask != nil {
            if viewModel.isEmbedded {
                embeddedEntryList
            } else {
                entryList
            }
        } else {
            emptyState
        }
    }

    // MARK: - List Layouts

    @ViewBuilder
    private var entryList: some View {
        List {
            syncStatusRow

            ForEach(viewModel.sections) { section in
                if section.title.isEmpty {
                    sectionRows(section, style: .list)
                } else {
                    Section(section.title) {
                        sectionRows(section, style: .list)
                    }
                }
            }

            if let migrationConfiguration = viewModel.migrationConfiguration {
                InlineTaskMigrationSection(
                    items: migrationConfiguration.destinationItems,
                    calendar: viewModel.calendar,
                    onMigrate: { item in migrationConfiguration.onDestinationMigration(item) },
                    onMigrateAll: migrationConfiguration.onDestinationMigrationAll
                )
                .listRowBackground(Color.clear)
            }

            if !viewModel.migratedNotes.isEmpty, let spread = viewModel.spread {
                MigratedEntriesSection(
                    spread: spread,
                    migratedTasks: [],
                    migratedNotes: viewModel.migratedNotes,
                    calendar: viewModel.calendar,
                    onEdit: { entry in viewModel.onEdit?(entry) },
                    onTaskTap: { task in viewModel.onOpenMigratedTask?(task) }
                )
                .listRowBackground(Color.clear)
            }

            if !viewModel.calendarEvents.isEmpty {
                Section("Events") {
                    ForEach(viewModel.calendarEvents) { event in
                        CalendarEventRow(event: event, calendar: viewModel.calendar)
                            .listRowInsets(Self.rowInsets)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture { eventKitService?.openEvent(event) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .environment(\.defaultMinListRowHeight, 0)
        .modifier(RefreshableModifier(onRefresh: viewModel.onRefresh))
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.list)
    }

    @ViewBuilder
    private var embeddedEntryList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.sections) { section in
                if !section.title.isEmpty {
                    Text(section.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(EdgeInsets(
                            top: 12,
                            leading: Self.rowInsets.leading,
                            bottom: 4,
                            trailing: Self.rowInsets.trailing
                        ))
                }
                sectionRows(section, style: .embedded)
            }

            if let migrationConfiguration = viewModel.migrationConfiguration {
                InlineTaskMigrationSection(
                    items: migrationConfiguration.destinationItems,
                    calendar: viewModel.calendar,
                    onMigrate: { item in migrationConfiguration.onDestinationMigration(item) },
                    onMigrateAll: migrationConfiguration.onDestinationMigrationAll
                )
                .padding(.horizontal, Self.rowInsets.leading)
            }

            if !viewModel.migratedNotes.isEmpty, let spread = viewModel.spread {
                MigratedEntriesSection(
                    spread: spread,
                    migratedTasks: [],
                    migratedNotes: viewModel.migratedNotes,
                    calendar: viewModel.calendar,
                    onEdit: { entry in viewModel.onEdit?(entry) },
                    onTaskTap: { task in viewModel.onOpenMigratedTask?(task) }
                )
                .padding(.horizontal, Self.rowInsets.leading)
            }
        }
    }

    // MARK: - Section Rows

    private enum SectionRowStyle { case list, embedded }

    @ViewBuilder
    private func sectionRows(_ section: EntryListSection, style: SectionRowStyle) -> some View {
        ForEach(section.entries, id: \.id) { entry in
            let row = entryRow(for: entry, contextualLabel: section.contextualLabel(for: entry))
            switch style {
            case .list:
                row
                    .listRowInsets(Self.rowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            case .embedded:
                row.padding(Self.rowInsets)
            }
        }

        if viewModel.onAddTask != nil {
            let target = viewModel.creationTarget(for: section)
            if viewModel.activeInlineCreationTarget?.sectionID == section.id {
                let inlineRow = inlineCreationRow(for: target)
                switch style {
                case .list:
                    inlineRow
                        .listRowInsets(Self.rowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                case .embedded:
                    inlineRow.padding(Self.rowInsets)
                }
            } else {
                let addButton = addTaskButton(for: target)
                switch style {
                case .list:
                    addButton
                        .listRowInsets(Self.rowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                case .embedded:
                    addButton.padding(Self.rowInsets)
                }
            }
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func entryRow(for entry: any Entry, contextualLabel: String?) -> some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                taskRow(task, contextualLabel: contextualLabel)
            }
        case .event:
            EmptyView()
        case .note:
            if let note = entry as? DataModel.Note {
                noteRow(note, contextualLabel: contextualLabel)
            }
        }
    }

    private func taskRow(_ task: DataModel.Task, contextualLabel: String?) -> some View {
        let rowStatus = viewModel.rowStatus(for: task)
        let sourceMigrationDestination = viewModel.migrationConfiguration?.sourceDestinations[task.id]
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
            iconConfiguration: StatusIconConfiguration(
                entryType: .task,
                taskStatus: rowStatus
            ),
            onComplete: rowStatus == .open ? { viewModel.onComplete?(task) } : nil,
            onMigrate: rowStatus == .open ? sourceMigrationDestination.map { destination in
                {
                    viewModel.pendingSourceMigration = EntryListViewModel.PendingSourceMigration(
                        task: task,
                        destination: destination
                    )
                }
            } : nil,
            onEdit: {
                viewModel.dismissActiveInlineEditing()
                if rowStatus == .migrated {
                    viewModel.onOpenMigratedTask?(task)
                } else {
                    viewModel.onEdit?(task)
                }
            },
            onDelete: { viewModel.onDelete?(task) },
            onTitleCommit: { @MainActor newTitle in
                await viewModel.onTitleCommit?(task, newTitle)
            },
            trailingAction: rowStatus == .open ? sourceMigrationDestination.map { destination in
                EntryRowTrailingAction(
                    systemImage: "arrow.right",
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton(task.title),
                    action: {
                        viewModel.pendingSourceMigration = EntryListViewModel.PendingSourceMigration(
                            task: task,
                            destination: destination
                        )
                    }
                )
            } : nil,
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

    private func noteRow(_ note: DataModel.Note, contextualLabel: String?) -> some View {
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


    // MARK: - Inline Creation

    private func inlineCreationRow(for target: EntryListViewModel.InlineCreationTarget) -> some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(entryType: .task, taskStatus: .open, color: .primary)
                .frame(width: 24, height: 24)

            TextField("New task", text: $viewModel.inlineTitle)
                .id(viewModel.inlineCreationID)
                .textFieldStyle(.plain)
                .font(SpreadTheme.Typography.body)
                .focused($isInlineFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.commitInlineTask(target: target) }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isInlineFocused = true
                    }
                }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField
                )

            Spacer()
        }
    }

    private func addTaskButton(for target: EntryListViewModel.InlineCreationTarget) -> some View {
        Button {
            viewModel.activateInlineCreation(for: target)
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
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton)
    }

    // MARK: - Helpers

    private func dismissInlineCreation() {
        viewModel.dismissInlineCreation()
        isInlineFocused = false
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        if let status = viewModel.syncStatus, status != .localOnly {
            Text(status.pullIndicatorTitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Entries", systemImage: "tray")
        } description: {
            Text("Add tasks or notes to this spread.")
        }
    }
}

// MARK: - Refresh Helpers

/// Conditionally applies `.refreshable` only when an action is provided.
private struct RefreshableModifier: ViewModifier {
    let onRefresh: (() async -> Void)?

    func body(content: Content) -> some View {
        if let onRefresh {
            content.refreshable { await onRefresh() }
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("Day Spread - Flat List") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let grouper = EntryListGrouper(
        configuration: .init(),
        period: .day,
        spreadDate: today,
        spreadStartDate: nil,
        spreadEndDate: nil,
        calendar: calendar
    )
    let tasks = [
        DataModel.Task(title: "Task 1", date: today),
        DataModel.Task(title: "Task 2", date: today)
    ]
    let notes = [DataModel.Note(title: "A note", date: today)]
    let entries: [any Entry] = tasks + notes
    let vm = EntryListViewModel()
    vm.sections = grouper.group(entries)
    vm.calendar = calendar
    vm.today = today
    vm.spread = spread
    return EntryListView(viewModel: vm)
}

#Preview("Day Spread - With Add Task") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let grouper = EntryListGrouper(
        configuration: .init(),
        period: .day,
        spreadDate: today,
        spreadStartDate: nil,
        spreadEndDate: nil,
        calendar: calendar
    )
    let tasks = [DataModel.Task(title: "Existing task", date: today)]
    let vm = EntryListViewModel()
    vm.sections = grouper.group(tasks)
    vm.calendar = calendar
    vm.today = today
    vm.spread = spread
    vm.onAddTask = { _, _, _ in }
    return EntryListView(viewModel: vm)
}

#Preview("Empty State") {
    let vm = EntryListViewModel()
    vm.calendar = .current
    vm.today = Date()
    return EntryListView(viewModel: vm)
}

#Preview("All Entry Types") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let grouper = EntryListGrouper(
        configuration: .init(),
        period: .day,
        spreadDate: today,
        spreadStartDate: nil,
        spreadEndDate: nil,
        calendar: calendar
    )
    let tasks: [any Entry] = [
        DataModel.Task(title: "Open task", date: today, status: .open),
        DataModel.Task(title: "Complete task", date: today, status: .complete),
        DataModel.Task(title: "Cancelled task", date: today, status: .cancelled)
    ]
    let notes: [any Entry] = [
        DataModel.Note(title: "Active note", date: today, status: .active)
    ]
    let vm = EntryListViewModel()
    vm.sections = grouper.group(tasks + notes)
    vm.calendar = calendar
    vm.today = today
    vm.spread = spread
    return EntryListView(viewModel: vm)
}
