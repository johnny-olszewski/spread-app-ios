import SwiftUI

/// Main spreads view for conventional mode.
///
/// Combines the spread title navigator with the spread content area.
/// The navigator provides navigation between spreads, and the content area
/// shows the selected spread's entries.
///
/// On iPad (regular width), the inbox button appears in this view's toolbar.
struct ConventionalSpreadsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Properties

    /// The journal manager providing spread data.
    @Bindable var journalManager: JournalManager

    /// The auth manager for handling authentication.
    let authManager: AuthManager

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Coordinates sheet presentation for this view.
    @State private var coordinator = SpreadsCoordinator()

    /// The currently selected spread.
    @State private var selectedSpread: DataModel.Spread?
    @State private var recenterToken = 0
    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding = TodayMissingSpreadRecommendationProvider()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            SpreadTitleNavigatorView(
                stripModel: conventionalStripModel,
                recenterToken: recenterToken,
                onRecommendedSpreadTapped: { openRecommendedSpreadCreation($0) },
                recommendationProvider: recommendationProvider,
                selection: conventionalSelectionBinding
            )

            Divider()

            if case .error = syncEngine?.status {
                SyncErrorBanner()
            }

            contentArea
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                InboxButton(inboxCount: journalManager.inboxCount) {
                    coordinator.showInbox()
                }
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                AuthButton(isSignedIn: authManager.state.isSignedIn) {
                    coordinator.showAuth()
                }
            }
        }
        .sheet(item: $coordinator.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
        .onAppear {
            resetSelectionIfNeeded()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: overlayAlignment) {
            spreadContent
            spreadOverlayButtons
        }
    }

    @ViewBuilder
    private var spreadContent: some View {
        let items = conventionalStripModel.items(for: .conventional(currentSelectedSpread))
        if !items.isEmpty {
            SpreadContentPagerView(
                model: conventionalStripModel,
                items: items,
                recenterToken: recenterToken,
                selection: conventionalSelectionBinding
            ) { item in
                conventionalPage(for: item)
            }
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above or create a new one.")
            }
        }
    }

    /// Returns the spread data model for the given spread.
    private func spreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }

    private var conventionalHeaderNavigatorModel: SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: journalManager.calendar,
            today: journalManager.today,
            spreads: journalManager.spreads,
            tasks: [],
            notes: [],
            events: []
        )
    }

    private var conventionalStripModel: SpreadTitleNavigatorModel {
        SpreadTitleNavigatorModel(
            headerModel: conventionalHeaderNavigatorModel,
            overdueItems: journalManager.overdueTaskItems
        )
    }

    private var currentSelectionID: String {
        SpreadHeaderNavigatorModel.Selection.conventional(currentSelectedSpread)
            .stableID(calendar: journalManager.calendar)
    }

    private var conventionalSelectionBinding: Binding<SpreadHeaderNavigatorModel.Selection> {
        Binding(
            get: {
                .conventional(currentSelectedSpread)
            },
            set: { newValue in
                guard case .conventional(let spread) = newValue else { return }
                selectedSpread = spread
            }
        )
    }

    private var currentSelectedSpread: DataModel.Spread {
        selectedSpread ?? fallbackSelectedSpread()
    }

    private func fallbackSelectedSpread() -> DataModel.Spread {
        SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        ).initialSelection(for: journalManager.today)
        ?? journalManager.spreads.first
        ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
    }

    private func navigateToToday() {
        guard let targetSpread = SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        ).initialSelection(for: journalManager.today) else {
            return
        }

        if currentSelectedSpread.id == targetSpread.id {
            recenterToken += 1
        } else {
            selectedSpread = targetSpread
        }
    }

    private var overlayAlignment: Alignment {
        horizontalSizeClass == .regular ? .topTrailing : .bottomLeading
    }

    @ViewBuilder
    private var spreadOverlayButtons: some View {
        HStack(spacing: 12) {
            Button("Today", action: navigateToToday)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.clear, in: Capsule())
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
                )

            Menu {
                Button(action: { coordinator.showSpreadCreation() }) {
                    Label("Create Spread", systemImage: "book")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)

                Button(action: { coordinator.showTaskCreation() }) {
                    Label("Create Task", systemImage: "circle.fill")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)

                Button(action: { coordinator.showNoteCreation() }) {
                    Label("Create Note", systemImage: "minus")
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createNote)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.accentColor)
                    .glassEffect(.clear, in: Capsule())
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.button)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func conventionalPage(for item: SpreadTitleNavigatorModel.Item) -> some View {
        if case .conventional(let spread) = item.selection {
            SpreadContentView(
                spread: spread,
                spreadDataModel: spreadDataModel(for: spread),
                calendar: journalManager.calendar,
                today: journalManager.today,
                onEditTask: { coordinator.showTaskDetail($0) },
                onEditNote: { coordinator.showNoteDetail($0) },
                onDeleteTask: { task in
                    Task { @MainActor in
                        try? await journalManager.deleteTask(task)
                        await syncEngine?.syncNow()
                    }
                },
                onDeleteNote: { note in
                    Task { @MainActor in
                        try? await journalManager.deleteNote(note)
                        await syncEngine?.syncNow()
                    }
                },
                onCompleteTask: { task in
                    Task { @MainActor in
                        let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                        try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                        await syncEngine?.syncNow()
                    }
                },
                onUpdateTaskTitle: { task, newTitle in
                    try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                    Task { @MainActor in
                        await syncEngine?.syncNow()
                    }
                },
                onReassignTask: { task, date, period in
                    try? await journalManager.updateTaskDateAndPeriod(task, newDate: date, newPeriod: period)
                    await syncEngine?.syncNow()
                },
                onAddTask: { title, date, period in
                    try await journalManager.addTask(title: title, date: date, period: period)
                    Task { @MainActor in
                        await syncEngine?.syncNow()
                    }
                },
                onOpenMigratedTask: { task in
                    openMigratedTask(task, from: spread)
                },
                onRefresh: {
                    guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
                    await engine.syncNow()
                },
                syncStatus: syncEngine?.status,
                headerNavigatorModel: conventionalHeaderNavigatorModel,
                migrationConfiguration: migrationConfiguration(for: spread),
                onSelectSpread: {
                    selectedSpread = $0
                }
            )
        } else {
            Color.clear
        }
    }

    private func openRecommendedSpreadCreation(_ recommendation: SpreadTitleNavigatorRecommendation) {
        coordinator.showSpreadCreation(
            prefill: .init(period: recommendation.period, date: recommendation.date)
        )
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(
        for destination: SpreadsCoordinator.SheetDestination
    ) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            SpreadCreationSheet(
                journalManager: journalManager,
                firstWeekday: journalManager.firstWeekday,
                initialPeriod: prefill?.period,
                initialDate: prefill?.date,
                onSpreadCreated: { spread in
                    selectedSpread = spread
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpread,
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpread,
                onNoteCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .taskDetail(let task):
            TaskDetailSheet(
                task: task,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteDetail(let note):
            NoteDetailSheet(
                note: note,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .inbox:
            InboxSheetView(journalManager: journalManager)
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    // MARK: - Migration

    private func migrationConfiguration(
        for spread: DataModel.Spread
    ) -> EntryListMigrationConfiguration? {
        guard spread.period != .multiday else { return nil }

        let sourceDestinations: [UUID: DataModel.Spread] = Dictionary(
            uniqueKeysWithValues: (spreadDataModel(for: spread)?.tasks ?? []).compactMap { task in
                guard let destination = journalManager.migrationDestination(for: task, on: spread) else {
                    return nil
                }
                return (task.id, destination)
            }
        )

        let destinationItems = journalManager.parentHierarchyMigrationCandidates(to: spread).map { candidate in
            EntryListMigrationConfiguration.DestinationItem(
                task: candidate.task,
                source: candidate.sourceSpread ?? spread
            )
        }

        guard !sourceDestinations.isEmpty || !destinationItems.isEmpty else {
            return nil
        }

        return EntryListMigrationConfiguration(
            sourceDestinations: sourceDestinations,
            destinationItems: destinationItems,
            onSourceMigrationConfirmed: { task, destination in
                migrateTask(task, from: spread, to: destination)
            },
            onDestinationMigration: { item in
                migrateTask(item.task, from: item.source, to: spread)
            },
            onDestinationMigrationAll: {
                migrateTasks(destinationItems, to: spread)
            }
        )
    }

    private func migrateTask(
        _ task: DataModel.Task,
        from source: DataModel.Spread,
        to destination: DataModel.Spread
    ) {
        Task { @MainActor in
            try? await journalManager.migrateTask(task, from: source, to: destination)
            await syncEngine?.syncNow()
        }
    }

    private func migrateTasks(
        _ items: [EntryListMigrationConfiguration.DestinationItem],
        to destination: DataModel.Spread
    ) {
        Task { @MainActor in
            for item in items {
                try? await journalManager.migrateTask(item.task, from: item.source, to: destination)
            }
            await syncEngine?.syncNow()
        }
    }

    private func openMigratedTask(_ task: DataModel.Task, from source: DataModel.Spread) {
        guard let destination = journalManager.currentDestinationSpread(for: task, excluding: source) else {
            coordinator.showTaskDetail(task)
            return
        }

        selectedSpread = destination
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            coordinator.showTaskDetail(task)
        }
    }

    private func resetSelectionIfNeeded() {
        if let selectedSpread, journalManager.spreads.contains(where: { $0.id == selectedSpread.id }) {
            return
        }

        let organizer = SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        )
        selectedSpread = organizer.initialSelection(for: journalManager.today)
    }
}

/// Spread content view displaying header and entry list.
///
/// Shows the spread header with title and entry counts, followed by
/// the entry list grouped by period. Uses dot grid paper background
/// per visual design spec.
private struct SpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let calendar: Calendar
    let today: Date

    /// Callback when a task is tapped for editing.
    var onEditTask: ((DataModel.Task) -> Void)?

    /// Callback when a note is tapped for editing.
    var onEditNote: ((DataModel.Note) -> Void)?

    /// Callback when a task is deleted via swipe.
    var onDeleteTask: ((DataModel.Task) -> Void)?

    /// Callback when a note is deleted via swipe.
    var onDeleteNote: ((DataModel.Note) -> Void)?

    /// Callback when a task is marked complete via swipe.
    var onCompleteTask: ((DataModel.Task) -> Void)?

    /// Callback when a task title is committed via inline edit.
    var onUpdateTaskTitle: (@MainActor (DataModel.Task, String) async -> Void)?
    var onReassignTask: (@MainActor (DataModel.Task, Date, Period) async -> Void)?

    /// Callback when a new task should be created inline.
    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil

    /// Callback invoked when the user pulls to refresh.
    var onRefresh: (() async -> Void)?

    /// The current sync status, used to populate the pull-to-refresh indicator title.
    var syncStatus: SyncStatus?

    let headerNavigatorModel: SpreadHeaderNavigatorModel
    var migrationConfiguration: EntryListMigrationConfiguration?
    var onSelectSpread: ((DataModel.Spread) -> Void)?

    @State private var isShowingNavigator = false

    var body: some View {
        VStack(spacing: 0) {
            SpreadHeaderView(
                configuration: SpreadHeaderConfiguration(
                    spread: spread,
                    calendar: calendar,
                    taskCount: spreadDataModel?.tasks.count ?? 0,
                    noteCount: spreadDataModel?.notes.count ?? 0
                ),
                isShowingNavigator: $isShowingNavigator,
                navigatorModel: headerNavigatorModel,
                currentSpread: spread,
                onNavigatorSelect: { selection in
                    guard case .conventional(let selectedSpread) = selection else { return }
                    onSelectSpread?(selectedSpread)
                }
            )

            // Entry list grouped by period
            entryList
        }
        .dotGridBackground(.paper)
    }

    @ViewBuilder
    private var entryList: some View {
        if let dataModel = spreadDataModel {
            EntryListView(
                spreadDataModel: dataModel,
                calendar: calendar,
                today: today,
                onEdit: { entry in
                    if let task = entry as? DataModel.Task {
                        onEditTask?(task)
                    } else if let note = entry as? DataModel.Note {
                        onEditNote?(note)
                    }
                },
                onOpenMigratedTask: { task in
                    onOpenMigratedTask?(task)
                },
                onDelete: { entry in
                    if let task = entry as? DataModel.Task {
                        onDeleteTask?(task)
                    } else if let note = entry as? DataModel.Note {
                        onDeleteNote?(note)
                    }
                },
                onComplete: { task in
                    onCompleteTask?(task)
                },
                migrationConfiguration: migrationConfiguration,
                onTitleCommit: { @MainActor task, newTitle in
                    await onUpdateTaskTitle?(task, newTitle)
                },
                onReassignTask: { @MainActor task, date, period in
                    await onReassignTask?(task, date, period)
                },
                onAddTask: { @MainActor title, date, period in
                    try await onAddTask?(title, date, period)
                },
                onRefresh: onRefresh,
                syncStatus: syncStatus
            )
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

}

// MARK: - Preview

#Preview {
    ConventionalSpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil
    )
}
