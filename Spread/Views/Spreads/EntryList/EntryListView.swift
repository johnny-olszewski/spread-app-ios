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

        var id: UUID { task.id }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Properties

    /// The spread data model containing entries.
    let spreadDataModel: SpreadDataModel

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The current date for determining past event status (v2 only).
    let today: Date

    let configuration: EntryListConfiguration

    /// Callback when an entry is tapped for editing.
    var onEdit: ((any Entry) -> Void)?
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil

    /// Callback when an entry should be deleted.
    var onDelete: ((any Entry) -> Void)?

    /// Callback when a task is marked complete.
    var onComplete: ((DataModel.Task) -> Void)?

    /// Callback when an entry should be migrated.
    var onMigrate: ((any Entry) -> Void)?

    /// Optional migration affordances for conventional spread lists.
    var migrationConfiguration: EntryListMigrationConfiguration?

    /// Callback when a task title is committed via inline edit.
    var onTitleCommit: (@MainActor (DataModel.Task, String) async -> Void)?

    /// Callback when a task's preferred date/period should be reassigned inline.
    var onReassignTask: (@MainActor (DataModel.Task, Date, Period) async -> Void)?

    /// Callback when a new task should be created inline.
    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil
    var onSelectSpread: ((DataModel.Spread) -> Void)? = nil
    var onCreateSpread: ((Date) -> Void)? = nil

    /// Callback invoked when the user pulls to refresh. `nil` disables pull-to-refresh.
    var onRefresh: (() async -> Void)?

    /// The current sync status, used to populate the pull-to-refresh indicator title.
    var syncStatus: SyncStatus?

    // MARK: - Inline creation state

    @State private var activeInlineCreationTarget: InlineCreationTarget?
    @State private var inlineTitle: String = ""
    @State private var inlineCreationID: UUID = UUID()
    @State private var activeInlineTaskID: UUID?
    @State private var pendingSourceMigration: PendingSourceMigration?
    @State private var hasAcquiredInlineCreationFocus = false
    @FocusState private var isInlineFocused: Bool

    init(
        spreadDataModel: SpreadDataModel,
        calendar: Calendar,
        today: Date,
        configuration: EntryListConfiguration = .init(),
        onEdit: ((any Entry) -> Void)? = nil,
        onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil,
        onDelete: ((any Entry) -> Void)? = nil,
        onComplete: ((DataModel.Task) -> Void)? = nil,
        onMigrate: ((any Entry) -> Void)? = nil,
        migrationConfiguration: EntryListMigrationConfiguration? = nil,
        onTitleCommit: (@MainActor (DataModel.Task, String) async -> Void)? = nil,
        onReassignTask: (@MainActor (DataModel.Task, Date, Period) async -> Void)? = nil,
        onAddTask: (@MainActor (String, Date, Period) async throws -> Void)? = nil,
        explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil,
        onSelectSpread: ((DataModel.Spread) -> Void)? = nil,
        onCreateSpread: ((Date) -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil,
        syncStatus: SyncStatus? = nil
    ) {
        self.spreadDataModel = spreadDataModel
        self.calendar = calendar
        self.today = today
        self.configuration = configuration
        self.onEdit = onEdit
        self.onOpenMigratedTask = onOpenMigratedTask
        self.onDelete = onDelete
        self.onComplete = onComplete
        self.onMigrate = onMigrate
        self.migrationConfiguration = migrationConfiguration
        self.onTitleCommit = onTitleCommit
        self.onReassignTask = onReassignTask
        self.onAddTask = onAddTask
        self.explicitDaySpreadForDate = explicitDaySpreadForDate
        self.onSelectSpread = onSelectSpread
        self.onCreateSpread = onCreateSpread
        self.onRefresh = onRefresh
        self.syncStatus = syncStatus
    }

    // MARK: - Computed Properties

    /// Entries combined from the spread data model for normal list rendering.
    private var displayedEntries: [any Entry] {
        EntryListDisplaySupport.displayedEntries(
            for: spreadDataModel,
            configuration: configuration,
            calendar: calendar
        )
    }

    /// Tasks rendered in the normal list, including cancelled and migrated rows.
    private var displayedTasks: [DataModel.Task] {
        spreadDataModel.tasks
    }

    /// Notes that are not migrated on this spread.
    private var displayedNotes: [DataModel.Note] {
        EntryListDisplaySupport.displayedNotes(
            for: spreadDataModel,
            configuration: configuration,
            calendar: calendar
        )
    }

    /// Notes migrated from this spread (have a migrated assignment on this spread).
    private var migratedNotes: [DataModel.Note] {
        EntryListDisplaySupport.migratedNotes(
            for: spreadDataModel,
            configuration: configuration,
            calendar: calendar
        )
    }

    /// Formatter for computing migration destination labels.
    private var destinationFormatter: MigrationDestinationFormatter {
        MigrationDestinationFormatter(calendar: calendar)
    }

    /// Grouped sections for display.
    private var sections: [EntryListSection] {
        let grouper = EntryListGrouper(
            configuration: configuration,
            period: spreadDataModel.spread.period,
            spreadDate: spreadDataModel.spread.date,
            spreadStartDate: spreadDataModel.spread.startDate,
            spreadEndDate: spreadDataModel.spread.endDate,
            calendar: calendar
        )
        return grouper.group(displayedEntries)
    }

    private var isMultidaySpread: Bool {
        spreadDataModel.spread.period == .multiday
    }

    private var multidayColumnCount: Int {
        MultidaySectionLayout.columnCount(for: horizontalSizeClass)
    }

    /// Whether there are any entries or migration affordances to display.
    private var hasAnyEntries: Bool {
        !displayedEntries.isEmpty ||
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
                if focused {
                    hasAcquiredInlineCreationFocus = true
                    return
                }

                guard hasAcquiredInlineCreationFocus, activeInlineCreationTarget != nil else { return }
                let trimmed = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    dismissInlineCreation()
                } else if let target = activeInlineCreationTarget {
                    commitInlineTask(target: target)
                }
            }
            .onChange(of: activeInlineCreationTarget) { _, target in
                guard target != nil else { return }
                hasAcquiredInlineCreationFocus = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    isInlineFocused = true
                }
            }
            .alert(item: $pendingSourceMigration) { migration in
                Alert(
                    title: Text("Migrate Task"),
                    message: Text("Move \"\(migration.task.title)\" to \(sourceMigrationDestinationTitle(for: migration.destination))?"),
                    primaryButton: .default(Text("Migrate")) {
                        migrationConfiguration?.onSourceMigrationConfirmed(migration.task, migration.destination)
                    },
                    secondaryButton: .cancel()
                )
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isMultidaySpread, configuration.groupingStyle != .flat {
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

            if let migrationConfiguration, configuration.showsMigrationHistory {
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
            if configuration.showsMigrationHistory {
                MigratedEntriesSection(
                    spread: spreadDataModel.spread,
                    migratedTasks: [],
                    migratedNotes: migratedNotes,
                    calendar: calendar,
                    onEdit: { entry in onEdit?(entry) },
                    onTaskTap: { task in
                        onOpenMigratedTask?(task)
                    }
                )
                .listRowBackground(Color.clear)
            }

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
                    if section.creationPeriod == .multiday {
                        multidayAssignmentSection(section)
                            .gridCellColumns(multidayColumnCount)
                    } else {
                        multidayDaySection(section)
                    }
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
        let isMigratedRow = configuration.showsMigrationHistory && isMigratedOnSpread(task)
        let rowStatus: DataModel.Task.Status = isMigratedRow ? .migrated : task.status
        let sourceMigrationDestination = migrationConfiguration?.sourceDestinations[task.id]
        return EntryRowView(
            configuration: EntryRowConfiguration(
                entryType: .task,
                taskStatus: rowStatus,
                title: task.title,
                migrationDestination: isMigratedRow
                    ? destinationFormatter.destination(for: task, from: spreadDataModel.spread)
                    : nil,
                contextualLabel: contextualLabel,
                taskBodyPreview: bodyPreview(for: task),
                taskPriority: task.priority,
                taskDueDateLabel: dueDateLabel(for: task),
                isTaskDueDateHighlighted: isDueDateHighlighted(for: task)
            ),
            iconConfiguration: StatusIconConfiguration(
                entryType: .task,
                taskStatus: rowStatus
            ),
            onComplete: rowStatus == .open ? { onComplete?(task) } : nil,
            onMigrate: rowStatus == .open ? sourceMigrationDestination.map { destination in
                {
                    pendingSourceMigration = PendingSourceMigration(task: task, destination: destination)
                }
            } : nil,
            onEdit: {
                dismissActiveInlineEditing()
                if isMigratedRow {
                    onOpenMigratedTask?(task)
                } else {
                    onEdit?(task)
                }
            },
            onDelete: { onDelete?(task) },
            onTitleCommit: { @MainActor newTitle in
                await onTitleCommit?(task, newTitle)
            },
            trailingAction: rowStatus == .open ? sourceMigrationDestination.map { destination in
                EntryRowTrailingAction(
                    systemImage: "arrow.right",
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton(task.title),
                    action: {
                        pendingSourceMigration = PendingSourceMigration(task: task, destination: destination)
                    }
                )
            } : nil,
            inlineActionConfiguration: rowStatus == .open ? inlineActionConfiguration(for: task) : nil,
            isInlineActive: activeInlineTaskID == task.id,
            onBeginInlineEditing: {
                activeInlineTaskID = task.id
            },
            onEndInlineEditing: {
                if activeInlineTaskID == task.id {
                    activeInlineTaskID = nil
                }
            }
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.taskRow(task.title))
    }

    private func noteRow(_ note: DataModel.Note, contextualLabel: String?) -> some View {
        EntryRowView(
            note: note,
            migrationDestination: destinationFormatter.destination(for: note, from: spreadDataModel.spread),
            contextualLabel: contextualLabel,
            onEdit: {
                dismissActiveInlineEditing()
                onEdit?(note)
            },
            onDelete: { onDelete?(note) }
        )
    }

    @ViewBuilder
    private func multidayDaySection(_ section: EntryListSection) -> some View {
        let dateID = multidaySectionDateID(for: section.date)
        let isDayActive = activeInlineCreationTarget?.sectionID == section.id
        let explicitDaySpread = explicitDaySpreadForDate?(section.date)
        let visualState = MultidayDayCardSupport.visualState(
            for: section.date,
            today: today,
            explicitDaySpread: explicitDaySpread,
            calendar: calendar
        )
        let footerAction = MultidayDayCardSupport.footerAction(
            for: section.date,
            explicitDaySpread: explicitDaySpread
        )
        let overdueCount = multidayOverdueCount(for: section)

        MultidayDayCardView(
            dateID: dateID,
            visualState: visualState,
            footerAction: footerAction,
            overdueCount: overdueCount,
            shortMonthText: multidayShortMonthText(for: section.date),
            weekdayText: multidayWeekdayText(for: section.date),
            dayNumberText: multidayDayNumberText(for: section.date),
            footerAccessibilityLabel: multidayFooterAccessibilityLabel(for: footerAction),
            onFooterTap: {
                switch footerAction {
                case .navigate(let spread):
                    dismissActiveInlineEditing()
                    onSelectSpread?(spread)
                case .createDay(let date):
                    dismissActiveInlineEditing()
                    onCreateSpread?(date)
                }
            }
        ) {
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
                    Text("No entries for this day.")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayEmptyState(dateID)
                        )
                }
            }
        }
    }

    private func dismissActiveInlineEditing() {
        activeInlineTaskID = nil
    }

    private func multidayFooterAccessibilityLabel(for action: MultidayDayCardAction) -> String {
        switch action {
        case .navigate:
            return "Open day spread"
        case .createDay:
            return "Create day spread"
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

        if onAddTask != nil {
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
                .frame(width: 24, height: 24)

            TextField("New task", text: $inlineTitle)
                .id(inlineCreationID)
                .textFieldStyle(.plain)
                .font(SpreadTheme.Typography.body)
                .focused($isInlineFocused)
                .submitLabel(.done)
                .onSubmit { commitInlineTask(target: target) }
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

    private func addTaskButton(for target: InlineCreationTarget) -> some View {
        Button {
            activateInlineCreation(for: target)
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

    // MARK: - Inline Creation Helpers

    private func activateInlineCreation(for target: InlineCreationTarget) {
        dismissActiveInlineEditing()
        inlineTitle = ""
        inlineCreationID = UUID()
        activeInlineCreationTarget = target
    }

    private func commitInlineTask(target: InlineCreationTarget) {
        let trimmed = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismissInlineCreation()
            return
        }
        Task { @MainActor in
            let didCreate = await performInlineTaskAdd(title: trimmed, target: target)
            guard didCreate else { return }
            dismissInlineCreation()
        }
    }

    @MainActor
    private func performInlineTaskAdd(title: String, target: InlineCreationTarget) async -> Bool {
        do {
            try await onAddTask?(title, target.date, target.period)
            return true
        } catch {
            return false
        }
    }

    private func dismissInlineCreation() {
        activeInlineCreationTarget = nil
        inlineTitle = ""
        hasAcquiredInlineCreationFocus = false
        isInlineFocused = false
    }

    private func sourceMigrationDestinationTitle(for spread: DataModel.Spread) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long

        switch spread.period {
        case .year:
            return String(calendar.component(.year, from: spread.date))
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: spread.date)
        case .day, .multiday:
            return formatter.string(from: spread.date)
        }
    }

    private func creationTarget(for section: EntryListSection) -> InlineCreationTarget {
        InlineCreationTarget(
            sectionID: section.id,
            date: section.creationDate,
            period: section.creationPeriod
        )
    }

    private func multidayAssignmentSection(_ section: EntryListSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.entries, id: \.id) { entry in
                    entryRow(for: entry, contextualLabel: section.contextualLabel(for: entry))
                }

                if onAddTask != nil {
                    if activeInlineCreationTarget?.sectionID == section.id {
                        inlineCreationRow(for: creationTarget(for: section))
                    } else {
                        addTaskButton(for: creationTarget(for: section))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    // MARK: - Helpers

    /// Whether a task has a migrated assignment on this spread.
    private func isMigratedOnSpread(_ task: DataModel.Task) -> Bool {
        task.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(spread: spreadDataModel.spread, calendar: calendar)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Entries", systemImage: "tray")
        } description: {
            Text("Add tasks or notes to this spread.")
        }
    }

    private func inlineActionConfiguration(for task: DataModel.Task) -> EntryRowInlineActionConfiguration? {
        guard task.status == .open else { return nil }

        let migrationOptions = EntryRowInlineEditSupport.migrationOptions(
            for: task,
            today: today,
            calendar: calendar
        )

        return EntryRowInlineActionConfiguration(
            migrationOptions: migrationOptions,
            onEditSheet: {
                onEdit?(task)
            },
            onMigrationSelected: { option in
                await onReassignTask?(task, option.date, option.period)
            }
        )
    }

    private func multidayOverdueCount(for section: EntryListSection) -> Int {
        section.entries.reduce(into: 0) { count, entry in
            guard let task = entry as? DataModel.Task,
                  task.status == .open else {
                return
            }

            let isAssignedToCurrentMultiday = task.assignments.contains { assignment in
                assignment.status == .open &&
                assignment.matches(spread: spreadDataModel.spread, calendar: calendar)
            }

            guard isAssignedToCurrentMultiday,
                  let multidayEndDate = spreadDataModel.spread.endDate else {
                return
            }

            guard isOverdue(date: multidayEndDate, period: .day) else { return }
            count += 1
        }
    }

    private func isOverdue(date: Date, period: Period) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)

        switch period {
        case .day:
            return todayStart > date.startOfDay(calendar: calendar)
        case .month:
            let startOfMonth = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return false
            }
            return todayStart >= startOfNextMonth
        case .year:
            let startOfYear = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return false
            }
            return todayStart >= startOfNextYear
        case .multiday:
            return false
        }
    }

    private func bodyPreview(for task: DataModel.Task) -> String? {
        guard let body = task.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }
        return body
    }

    private func dueDateLabel(for task: DataModel.Task) -> String? {
        guard let dueDate = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return "Due \(formatter.string(from: dueDate))"
    }

    private func isDueDateHighlighted(for task: DataModel.Task) -> Bool {
        guard task.status == .open,
              let dueDate = task.dueDate else {
            return false
        }
        return dueDate.startOfDay(calendar: calendar) <= today.startOfDay(calendar: calendar)
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
