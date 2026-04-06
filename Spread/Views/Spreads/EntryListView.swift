import SwiftUI

/// Displays a list of entries with period-appropriate grouping.
///
/// Grouping rules:
/// - Year spread: Groups by month
/// - Month spread: Groups by day
/// - Day spread: Flat list (no grouping)
/// - Multiday spread: Groups by day within range
///
/// Uses `EntryRowView` for consistent entry rendering across all spread types.
struct EntryListView: View {

    private struct InlineCreationTarget: Equatable {
        let sectionID: Date
        let date: Date
        let period: Period
    }

    private struct PendingSourceMigration: Identifiable {
        let task: DataModel.Task
        let destination: DataModel.Spread

        var id: String {
            "\(task.id.uuidString)-\(destination.id.uuidString)"
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Properties

    /// The spread data model containing entries.
    let spreadDataModel: SpreadDataModel

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The current date for determining past event status (v2 only).
    let today: Date

    /// Callback when an entry is tapped for editing.
    var onEdit: ((any Entry) -> Void)?

    /// Callback when an entry should be deleted.
    var onDelete: ((any Entry) -> Void)?

    /// Callback when a task is marked complete.
    var onComplete: ((DataModel.Task) -> Void)?

    /// Callback when an entry should be migrated.
    var onMigrate: ((any Entry) -> Void)?

    /// Optional migration affordances for conventional spread lists.
    var migrationConfiguration: EntryListMigrationConfiguration?

    /// Callback when a task title is committed via inline edit.
    var onTitleCommit: ((DataModel.Task, String) -> Void)?

    /// Callback when a new task should be created inline.
    var onAddTask: ((String, Date, Period) async throws -> Void)?

    /// Callback invoked when the user pulls to refresh. `nil` disables pull-to-refresh.
    var onRefresh: (() async -> Void)?

    /// The current sync status, used to populate the pull-to-refresh indicator title.
    var syncStatus: SyncStatus?

    // MARK: - Inline creation state

    @State private var activeInlineCreationTarget: InlineCreationTarget?
    @State private var inlineTitle: String = ""
    @State private var isContinuingEntry: Bool = false
    @State private var inlineCreationID: UUID = UUID()
    @State private var pendingSourceMigration: PendingSourceMigration?
    @FocusState private var isInlineFocused: Bool

    // MARK: - Computed Properties

    /// Active (non-migrated) entries combined from the spread data model.
    private var activeEntries: [any Entry] {
        if isMultidaySpread {
            var entries: [any Entry] = []
            entries.append(contentsOf: activeTasks)
            return entries
        }

        var entries: [any Entry] = []
        entries.append(contentsOf: activeTasks)
        entries.append(contentsOf: activeNotes)
        return entries
    }

    /// Tasks that are not migrated on this spread.
    private var activeTasks: [DataModel.Task] {
        spreadDataModel.tasks.filter { task in
            !isMigratedOnSpread(task)
        }
    }

    /// Notes that are not migrated on this spread.
    private var activeNotes: [DataModel.Note] {
        if isMultidaySpread {
            return []
        }
        return spreadDataModel.notes.filter { note in
            !isMigratedOnSpread(note)
        }
    }

    /// Tasks migrated from this spread (have a migrated assignment on this spread).
    private var migratedTasks: [DataModel.Task] {
        spreadDataModel.tasks.filter { task in
            isMigratedOnSpread(task)
        }
    }

    /// Notes migrated from this spread (have a migrated assignment on this spread).
    private var migratedNotes: [DataModel.Note] {
        if isMultidaySpread {
            return []
        }
        return spreadDataModel.notes.filter { note in
            isMigratedOnSpread(note)
        }
    }

    /// Formatter for computing migration destination labels.
    private var destinationFormatter: MigrationDestinationFormatter {
        MigrationDestinationFormatter(calendar: calendar)
    }

    /// Grouped sections for display (active entries only).
    private var sections: [EntryListSection] {
        let grouper = EntryListGrouper(
            period: spreadDataModel.spread.period,
            spreadDate: spreadDataModel.spread.date,
            spreadStartDate: spreadDataModel.spread.startDate,
            spreadEndDate: spreadDataModel.spread.endDate,
            calendar: calendar
        )
        return grouper.group(activeEntries)
    }

    private var isMultidaySpread: Bool {
        spreadDataModel.spread.period == .multiday
    }

    private var multidayColumnCount: Int {
        MultidaySectionLayout.columnCount(for: horizontalSizeClass)
    }

    /// Whether there are any entries (active or migrated) to display.
    private var hasAnyEntries: Bool {
        !activeEntries.isEmpty ||
        !migratedTasks.isEmpty ||
        !migratedNotes.isEmpty ||
        !(migrationConfiguration?.destinationItems.isEmpty ?? true)
    }

    /// Row insets for the standard entry list, using theme-defined vertical spacing.
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
                            if let target = activeInlineCreationTarget {
                                commitInlineTask(target: target)
                            }
                        }
                        .glassEffect(in: Capsule())
                        .disabled(inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .onChange(of: isInlineFocused) { _, focused in
                guard !focused, !isContinuingEntry, activeInlineCreationTarget != nil else { return }
                let trimmed = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    dismissInlineCreation()
                } else if let target = activeInlineCreationTarget {
                    commitInlineTask(target: target)
                }
            }
            .alert(item: $pendingSourceMigration) { migration in
                Alert(
                    title: Text("Migrate task?"),
                    message: Text("Move \"\(migration.task.title)\" to \(spreadTitle(for: migration.destination))?"),
                    primaryButton: .default(
                        Text("Migrate"),
                        action: {
                            migrationConfiguration?.onSourceMigrationConfirmed(
                                migration.task,
                                migration.destination
                            )
                        }
                    ),
                    secondaryButton: .cancel()
                )
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isMultidaySpread {
            multidayEntryGrid
        } else if hasAnyEntries || onAddTask != nil {
            entryList
        } else {
            emptyState
        }
    }

    // MARK: - Subviews

    /// Subtle status row shown at the top of the list indicating last sync state.
    ///
    /// Scrolls out of view with content; becomes visible when the user pulls to the top.
    @ViewBuilder
    private var syncStatusRow: some View {
        if let status = syncStatus, status != .localOnly {
            Text(status.pullIndicatorTitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    @ViewBuilder
    private var entryList: some View {
        List {
            syncStatusRow

            ForEach(sections) { section in
                if section.title.isEmpty {
                    sectionRows(section)
                } else {
                    Section(section.title) {
                        sectionRows(section)
                    }
                }
            }

            if let migrationConfiguration {
                InlineTaskMigrationSection(
                    items: migrationConfiguration.destinationItems,
                    calendar: calendar,
                    onMigrate: { item in
                        migrationConfiguration.onDestinationMigration(item)
                    },
                    onMigrateAll: migrationConfiguration.onDestinationMigrationAll
                )
                .listRowBackground(Color.clear)
            }

            // Collapsible migrated entries section
            MigratedEntriesSection(
                spread: spreadDataModel.spread,
                migratedTasks: migratedTasks,
                migratedNotes: migratedNotes,
                calendar: calendar,
                onEdit: { entry in onEdit?(entry) }
            )
            .listRowBackground(Color.clear)

        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .environment(\.defaultMinListRowHeight, 0)
        .modifier(RefreshableModifier(onRefresh: onRefresh))
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.list)
    }

    private var multidayEntryGrid: some View {
        ScrollView {
            if let status = syncStatus, status != .localOnly {
                Text(status.pullIndicatorTitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                    count: multidayColumnCount
                ),
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(sections) { section in
                    multidayDaySection(section)
                }
            }
            .padding(16)
        }
        .modifier(RefreshableModifier(onRefresh: onRefresh))
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid)
    }

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
        EntryRowView(
            task: task,
            migrationDestination: destinationFormatter.destination(for: task, from: spreadDataModel.spread),
            contextualLabel: contextualLabel,
            onComplete: { onComplete?(task) },
            onEdit: { onEdit?(task) },
            onDelete: { onDelete?(task) },
            onTitleCommit: { newTitle in onTitleCommit?(task, newTitle) },
            trailingAction: sourceMigrationAction(for: task)
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.taskRow(task.title))
    }

    private func noteRow(_ note: DataModel.Note, contextualLabel: String?) -> some View {
        EntryRowView(
            note: note,
            migrationDestination: destinationFormatter.destination(for: note, from: spreadDataModel.spread),
            contextualLabel: contextualLabel,
            onEdit: { onEdit?(note) },
            onDelete: { onDelete?(note) }
        )
    }

    @ViewBuilder
    private func multidayDaySection(_ section: EntryListSection) -> some View {
        let dateID = multidaySectionDateID(for: section.date)
        let isDayActive = activeInlineCreationTarget?.sectionID == section.id

        VStack(alignment: .leading, spacing: 12) {
            multidayHeader(for: section.date)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(section.entries, id: \.id) { entry in
                    entryRow(for: entry, contextualLabel: section.contextualLabel(for: entry))
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                }

                if isDayActive {
                    inlineCreationRow(for: creationTarget(for: section))
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                } else if onAddTask != nil {
                    addTaskButton(for: creationTarget(for: section))
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayAddTaskButton(dateID)
                        )
                } else if section.entries.isEmpty {
                    Text("No tasks for this day.")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayEmptyState(dateID)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpreadTheme.Paper.primary.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12))
        )
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection(dateID)
        )
    }

    private func multidayHeader(for date: Date) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(multidayWeekdayText(for: date))
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 0) {
                Text(multidayShortMonthText(for: date))
                    .font(SpreadTheme.Typography.caption.smallCaps())
                    .foregroundStyle(.secondary)
                Text(multidayDayNumberText(for: date))
                    .font(SpreadTheme.Typography.title3)
                    .foregroundStyle(.primary)
            }
            .alignmentGuide(.lastTextBaseline) { dimensions in
                dimensions[.lastTextBaseline]
            }
        }
    }

    @ViewBuilder
    private func sectionRows(_ section: EntryListSection) -> some View {
        ForEach(section.entries, id: \.id) { entry in
            entryRow(for: entry, contextualLabel: section.contextualLabel(for: entry))
                .listRowInsets(Self.rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }

        if let onAddTask {
            if activeInlineCreationTarget?.sectionID == section.id {
                inlineCreationRow(for: creationTarget(for: section))
                    .listRowInsets(Self.rowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                addTaskButton(for: creationTarget(for: section))
                    .listRowInsets(Self.rowInsets)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    private func multidaySectionDateID(for date: Date) -> String {
        Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: date, calendar: calendar)
    }

    private func multidayWeekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func multidayShortMonthText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func multidayDayNumberText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    // MARK: - Inline Creation

    private func inlineCreationRow(for target: InlineCreationTarget) -> some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(entryType: .task, taskStatus: .open, color: .primary)

            TextField("New task", text: $inlineTitle)
                .id(inlineCreationID)
                .textFieldStyle(.plain)
                .focused($isInlineFocused)
                .submitLabel(.return)
                .onSubmit { commitAndContinue(target: target) }
                .onAppear { isInlineFocused = true }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField
                )

            Spacer()
        }
    }

    private func addTaskButton(for target: InlineCreationTarget) -> some View {
        Button {
            activateInlineCreation(for: target)
        } label: {
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 12)
                Text("Add Task")
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton)
    }

    // MARK: - Inline Creation Helpers

    private func activateInlineCreation(for target: InlineCreationTarget) {
        inlineTitle = ""
        activeInlineCreationTarget = target
    }

    private func commitAndContinue(target: InlineCreationTarget) {
        let trimmed = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismissInlineCreation()
            return
        }
        isContinuingEntry = true
        Task {
            try? await onAddTask?(trimmed, target.date, target.period)
            inlineTitle = ""
            isContinuingEntry = false
            inlineCreationID = UUID()
        }
    }

    private func commitInlineTask(target: InlineCreationTarget) {
        let trimmed = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismissInlineCreation()
            return
        }
        Task {
            try? await onAddTask?(trimmed, target.date, target.period)
            dismissInlineCreation()
        }
    }

    private func dismissInlineCreation() {
        guard !isContinuingEntry else { return }
        activeInlineCreationTarget = nil
        inlineTitle = ""
        isInlineFocused = false
    }

    private func creationTarget(for section: EntryListSection) -> InlineCreationTarget {
        InlineCreationTarget(
            sectionID: section.id,
            date: section.creationDate,
            period: section.creationPeriod
        )
    }

    // MARK: - Helpers

    /// Whether a task has a migrated assignment on this spread.
    private func isMigratedOnSpread(_ task: DataModel.Task) -> Bool {
        task.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(
                period: spreadDataModel.spread.period,
                date: spreadDataModel.spread.date,
                calendar: calendar
            )
        }
    }

    /// Whether a note has a migrated assignment on this spread.
    private func isMigratedOnSpread(_ note: DataModel.Note) -> Bool {
        note.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(
                period: spreadDataModel.spread.period,
                date: spreadDataModel.spread.date,
                calendar: calendar
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Entries", systemImage: "tray")
        } description: {
            Text("Add tasks or notes to this spread.")
        }
    }

    private func sourceMigrationAction(
        for task: DataModel.Task
    ) -> EntryRowTrailingAction? {
        guard let destination = migrationConfiguration?.sourceDestinations[task.id] else {
            return nil
        }

        return EntryRowTrailingAction(
            systemImage: "arrow.right",
            accessibilityIdentifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton(task.title),
            action: {
                pendingSourceMigration = PendingSourceMigration(
                    task: task,
                    destination: destination
                )
            }
        )
    }

    private func spreadTitle(for spread: DataModel.Spread) -> String {
        SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar
        ).title
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


enum MultidaySectionLayout {
    static func columnCount(for horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        horizontalSizeClass == .regular ? 2 : 1
    }
}

// MARK: - Preview

#Preview("Year Spread - Grouped by Month") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .year, date: today, calendar: calendar)
    let jan15 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    let feb10 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "January task 1", date: jan15),
            DataModel.Task(title: "January task 2", date: jan15),
            DataModel.Task(title: "February task", date: feb10)
        ],
        notes: [],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Month Spread - Grouped by Day") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .month, date: today, calendar: calendar)
    let day5 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
    let day10 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Day 5 task", date: day5),
            DataModel.Task(title: "Day 10 task", date: day10)
        ],
        notes: [],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Day Spread - Flat List") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Task 1", date: today),
            DataModel.Task(title: "Task 2", date: today)
        ],
        notes: [DataModel.Note(title: "A note", date: today)],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Empty State") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(spread: spread)
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Day Spread - With Add Task") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [DataModel.Task(title: "Existing task", date: today)],
        notes: [],
        events: []
    )
    EntryListView(
        spreadDataModel: dataModel,
        calendar: calendar,
        today: today,
        onAddTask: { _, _, _ in }
    )
}

#Preview("Multiday Spread - Grouped by Day") {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
    let endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
    let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
    let day6 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
    let day8 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 8))!
    let day10 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Day 6 task", date: day6),
            DataModel.Task(title: "Day 8 task 1", date: day8),
            DataModel.Task(title: "Day 8 task 2", date: day8)
        ],
        notes: [
            DataModel.Note(title: "Day 10 note", date: day10)
        ],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("All Entry Types") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Open task", date: today, status: .open),
            DataModel.Task(title: "Complete task", date: today, status: .complete),
            DataModel.Task(title: "Migrated task", date: today, status: .migrated),
            DataModel.Task(title: "Cancelled task", date: today, status: .cancelled)
        ],
        notes: [
            DataModel.Note(title: "Active note", date: today, status: .active),
            DataModel.Note(title: "Migrated note", date: today, status: .migrated)
        ],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}
