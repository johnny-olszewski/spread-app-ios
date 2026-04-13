import SwiftUI

struct SpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    let navigationState: SpreadsNavigationState

    @State private var viewModel = SpreadsViewModel()

    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding =
        TodayMissingSpreadRecommendationProvider()

    var body: some View {
        SharedSpreadsShellView(
            selection: selectionBinding,
            stripModel: stripModel,
            recenterToken: viewModel.recenterToken,
            recommendationProvider: recommendationProvider,
            onRecommendedSpreadTapped: onRecommendedSpreadTapped,
            authManager: authManager,
            onAuth: { viewModel.showAuth() },
            syncStatus: syncEngine?.status,
            controls: shellControls,
            items: stripItems
        ) { item in
            page(for: item)
        }
        .sheet(item: $viewModel.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            if journalManager.bujoMode == .conventional {
                resetConventionalSelectionIfNeeded()
            }
        }
        .onAppear {
            if viewModel.selectedSelection == nil {
                viewModel.selectedSelection = defaultSelection
            }
            handlePendingNavigationRequest()
        }
        .onChange(of: navigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
    }

    // MARK: - Selection

    private var selectionBinding: Binding<SpreadHeaderNavigatorModel.Selection> {
        Binding(
            get: { currentSelection },
            set: { viewModel.selectedSelection = $0 }
        )
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        viewModel.selectedSelection ?? defaultSelection
    }

    private var defaultSelection: SpreadHeaderNavigatorModel.Selection {
        switch journalManager.bujoMode {
        case .conventional:
            return .conventional(conventionalFallbackSpread())
        case .traditional:
            return .traditionalYear(defaultTraditionalYearDate)
        }
    }

    private var defaultTraditionalYearDate: Date {
        let calendar = journalManager.calendar
        let year = calendar.component(.year, from: journalManager.today)
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    // MARK: - Strip Model

    private var stripModel: SpreadTitleNavigatorModel {
        journalManager.titleNavigatorModel
    }

    private var stripItems: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    // MARK: - Shell Controls

    private var shellControls: SharedSpreadsShellControlConfiguration {
        SharedSpreadsShellControlConfiguration(
            showsTodayButton: true,
            onToday: navigateToToday,
            onCreateSpread: journalManager.bujoMode == .conventional
                ? { viewModel.showSpreadCreation() }
                : nil,
            onCreateTask: { viewModel.showTaskCreation() },
            onCreateNote: { viewModel.showNoteCreation() }
        )
    }

    private var onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)? {
        guard journalManager.bujoMode == .conventional else { return nil }
        return { recommendation in
            viewModel.showSpreadCreation(
                prefill: .init(period: recommendation.period, date: recommendation.date)
            )
        }
    }

    // MARK: - Navigation

    private func navigateToToday() {
        switch journalManager.bujoMode {
        case .conventional:
            guard let targetSpread = SpreadHierarchyOrganizer(
                spreads: journalManager.spreads,
                calendar: journalManager.calendar
            ).initialSelection(for: journalManager.today) else { return }

            if case .conventional(let current) = currentSelection, current.id == targetSpread.id {
                viewModel.recenterToken += 1
            } else {
                viewModel.selectedSelection = .conventional(targetSpread)
            }

        case .traditional:
            let target = SpreadHeaderNavigatorModel.Selection.traditionalDay(
                Period.day.normalizeDate(journalManager.today, calendar: journalManager.calendar)
            )
            if target.stableID(calendar: journalManager.calendar)
                == currentSelection.stableID(calendar: journalManager.calendar) {
                viewModel.recenterToken += 1
            } else {
                viewModel.selectedSelection = target
            }
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private func page(for item: SpreadTitleNavigatorModel.Item) -> some View {
        switch journalManager.bujoMode {
        case .conventional:
            conventionalPage(for: item)
        case .traditional:
            traditionalPage(for: item)
        }
    }

    @ViewBuilder
    private func conventionalPage(for item: SpreadTitleNavigatorModel.Item) -> some View {
        if case .conventional(let spread) = item.selection {
            SpreadSurfaceView(
                spread: spread,
                spreadDataModel: conventionalSpreadDataModel(for: spread),
                calendar: journalManager.calendar,
                today: journalManager.today,
                headerNavigatorModel: stripModel.headerModel,
                entryListConfiguration: .init(),
                accessoryContent: monthAccessory(for: spread),
                onEditTask: { viewModel.showTaskDetail($0) },
                onEditNote: { viewModel.showNoteDetail($0) },
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
                migrationConfiguration: migrationConfiguration(for: spread),
                onSelectSpread: { selection in
                    guard case .conventional(let selectedSpread) = selection else { return }
                    viewModel.selectedSelection = .conventional(selectedSpread)
                },
                explicitDaySpreadForDate: { date in
                    explicitDaySpread(for: date)
                },
                onCreateSpread: { date in
                    viewModel.showSpreadCreation(prefill: .init(period: .day, date: date))
                }
            )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func traditionalPage(for item: SpreadTitleNavigatorModel.Item) -> some View {
        switch item.selection {
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            let spread = traditionalSpread(for: item.selection)
            SpreadSurfaceView(
                spread: spread,
                spreadDataModel: traditionalSpreadDataModel(for: item.selection),
                calendar: journalManager.calendar,
                today: journalManager.today,
                headerNavigatorModel: stripModel.headerModel,
                entryListConfiguration: EntryListConfiguration(groupingStyle: .flat, showsMigrationHistory: false),
                accessoryContent: monthAccessory(for: spread),
                onEditTask: { viewModel.showTaskDetail($0) },
                onEditNote: { viewModel.showNoteDetail($0) },
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
                onRefresh: {
                    guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
                    await engine.syncNow()
                },
                syncStatus: syncEngine?.status,
                onSelectSpread: { selection in
                    switch selection {
                    case .traditionalYear, .traditionalMonth, .traditionalDay:
                        viewModel.selectedSelection = selection
                    case .conventional:
                        break
                    }
                }
            )
        case .conventional:
            Color.clear
        }
    }

    // MARK: - Conventional Helpers

    private func conventionalSpreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }

    private func conventionalFallbackSpread() -> DataModel.Spread {
        SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        ).initialSelection(for: journalManager.today)
        ?? journalManager.spreads.first
        ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
    }

    private func resetConventionalSelectionIfNeeded() {
        guard case .conventional(let spread) = viewModel.selectedSelection else { return }
        if journalManager.spreads.contains(where: { $0.id == spread.id }) { return }

        let organizer = SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        )
        if let newSelection = organizer.initialSelection(for: journalManager.today) {
            viewModel.selectedSelection = .conventional(newSelection)
        }
    }

    private func migrationConfiguration(for spread: DataModel.Spread) -> EntryListMigrationConfiguration? {
        guard spread.period != .multiday else { return nil }

        let sourceDestinations: [UUID: DataModel.Spread] = Dictionary(
            uniqueKeysWithValues: (conventionalSpreadDataModel(for: spread)?.tasks ?? []).compactMap { task in
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

        guard !sourceDestinations.isEmpty || !destinationItems.isEmpty else { return nil }

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
            viewModel.showTaskDetail(task)
            return
        }

        viewModel.selectedSelection = .conventional(destination)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            viewModel.showTaskDetail(task)
        }
    }

    private func explicitDaySpread(for date: Date) -> DataModel.Spread? {
        let normalizedDate = Period.day.normalizeDate(date, calendar: journalManager.calendar)
        return journalManager.spreads.first { spread in
            spread.period == .day &&
            journalManager.calendar.isDate(
                Period.day.normalizeDate(spread.date, calendar: journalManager.calendar),
                inSameDayAs: normalizedDate
            )
        }
    }

    // MARK: - Traditional Helpers

    private var traditionalService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: journalManager.calendar)
    }

    private func traditionalSpread(for selection: SpreadHeaderNavigatorModel.Selection) -> DataModel.Spread {
        switch selection {
        case .traditionalYear(let yearDate):
            return DataModel.Spread(period: .year, date: yearDate, calendar: journalManager.calendar)
        case .traditionalMonth(let monthDate):
            return DataModel.Spread(period: .month, date: monthDate, calendar: journalManager.calendar)
        case .traditionalDay(let dayDate):
            return DataModel.Spread(period: .day, date: dayDate, calendar: journalManager.calendar)
        case .conventional:
            return DataModel.Spread(period: .year, date: defaultTraditionalYearDate, calendar: journalManager.calendar)
        }
    }

    private func traditionalSpreadDataModel(
        for selection: SpreadHeaderNavigatorModel.Selection
    ) -> SpreadDataModel {
        let spread = traditionalSpread(for: selection)
        return traditionalService.virtualSpreadDataModel(
            period: spread.period,
            date: spread.date,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
    }

    // MARK: - Shared Helpers

    private func monthAccessory(for spread: DataModel.Spread) -> AnyView? {
        guard spread.period == .month else { return nil }
        let calendarMode: SpreadMonthCalendarView.Mode = journalManager.bujoMode == .conventional
            ? .conventional
            : .traditional
        return AnyView(
            SpreadMonthCalendarView(
                monthDate: spread.date,
                mode: calendarMode,
                journalManager: journalManager
            )
        )
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for destination: SpreadsViewModel.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            if journalManager.bujoMode == .conventional {
                SpreadCreationSheet(
                    journalManager: journalManager,
                    firstWeekday: journalManager.firstWeekday,
                    initialPeriod: prefill?.period,
                    initialDate: prefill?.date,
                    onSpreadCreated: { spread in
                        viewModel.selectedSelection = .conventional(spread)
                        Task { @MainActor in await syncEngine?.syncNow() }
                    }
                )
            } else {
                Color.clear
            }
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpreadForSheet,
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpreadForSheet,
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
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    private var selectedSpreadForSheet: DataModel.Spread? {
        switch currentSelection {
        case .conventional(let spread):
            return spread
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            return traditionalSpread(for: currentSelection)
        }
    }

    // MARK: - Pending Navigation

    private func handlePendingNavigationRequest() {
        guard let request = navigationState.pendingRequest else { return }

        switch request.selection {
        case .conventional(let spread):
            guard journalManager.bujoMode == .conventional else { return }
            viewModel.selectedSelection = .conventional(spread)
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            guard journalManager.bujoMode == .traditional else { return }
            viewModel.selectedSelection = request.selection
        }

        guard let task = journalManager.tasks.first(where: { $0.id == request.taskID }) else {
            navigationState.pendingRequest = nil
            return
        }

        Task { @MainActor in
            await Task.yield()
            viewModel.showTaskDetail(task)
            navigationState.pendingRequest = nil
        }
    }
}

#Preview {
    SpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil,
        navigationState: SpreadsNavigationState()
    )
}
