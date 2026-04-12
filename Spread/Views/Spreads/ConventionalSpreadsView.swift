import SwiftUI

struct ConventionalSpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    let navigationState: SpreadsNavigationState

    @State private var coordinator = SpreadsCoordinator()
    @State private var selectedSpread: DataModel.Spread?
    @State private var recenterToken = 0

    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding = TodayMissingSpreadRecommendationProvider()

    var body: some View {
        SharedSpreadsShellView(
            selection: conventionalSelectionBinding,
            stripModel: conventionalStripModel,
            recenterToken: recenterToken,
            recommendationProvider: recommendationProvider,
            onRecommendedSpreadTapped: { openRecommendedSpreadCreation($0) },
            authManager: authManager,
            onAuth: { coordinator.showAuth() },
            syncStatus: syncEngine?.status,
            controls: shellControls,
            items: conventionalStripItems
        ) { item in
            conventionalPage(for: item)
        }
        .sheet(item: $coordinator.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
        .onAppear {
            resetSelectionIfNeeded()
            handlePendingNavigationRequest()
        }
        .onChange(of: navigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
    }

    private var conventionalStripItems: [SpreadTitleNavigatorModel.Item] {
        conventionalStripModel.items(for: .conventional(currentSelectedSpread))
    }

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

    private var conventionalSelectionBinding: Binding<SpreadHeaderNavigatorModel.Selection> {
        Binding(
            get: { .conventional(currentSelectedSpread) },
            set: { newValue in
                guard case .conventional(let spread) = newValue else { return }
                selectedSpread = spread
            }
        )
    }

    private var currentSelectedSpread: DataModel.Spread {
        selectedSpread ?? fallbackSelectedSpread()
    }

    private var shellControls: SharedSpreadsShellControlConfiguration {
        SharedSpreadsShellControlConfiguration(
            showsTodayButton: true,
            onToday: navigateToToday,
            onCreateSpread: { coordinator.showSpreadCreation() },
            onCreateTask: { coordinator.showTaskCreation() },
            onCreateNote: { coordinator.showNoteCreation() }
        )
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

    @ViewBuilder
    private func conventionalPage(for item: SpreadTitleNavigatorModel.Item) -> some View {
        if case .conventional(let spread) = item.selection {
            SpreadSurfaceView(
                spread: spread,
                spreadDataModel: spreadDataModel(for: spread),
                calendar: journalManager.calendar,
                today: journalManager.today,
                headerNavigatorModel: conventionalHeaderNavigatorModel,
                entryListConfiguration: .init(),
                accessoryContent: monthAccessory(for: spread),
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
                migrationConfiguration: migrationConfiguration(for: spread),
                onSelectSpread: { selection in
                    guard case .conventional(let selectedSpread) = selection else { return }
                    self.selectedSpread = selectedSpread
                },
                explicitDaySpreadForDate: { date in
                    explicitDaySpread(for: date)
                },
                onCreateSpread: { date in
                    coordinator.showSpreadCreation(prefill: .init(period: .day, date: date))
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

    private func monthAccessory(for spread: DataModel.Spread) -> AnyView? {
        guard spread.period == .month else { return nil }
        return AnyView(
            SpreadMonthCalendarView(
                monthDate: spread.date,
                mode: .conventional,
                journalManager: journalManager
            )
        )
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

    @ViewBuilder
    private func sheetContent(for destination: SpreadsCoordinator.SheetDestination) -> some View {
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
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    private func migrationConfiguration(for spread: DataModel.Spread) -> EntryListMigrationConfiguration? {
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

    private func handlePendingNavigationRequest() {
        guard let request = navigationState.pendingRequest else { return }
        guard case .conventional(let spread) = request.selection else { return }

        selectedSpread = spread

        guard let task = journalManager.tasks.first(where: { $0.id == request.taskID }) else {
            navigationState.pendingRequest = nil
            return
        }

        Task { @MainActor in
            await Task.yield()
            coordinator.showTaskDetail(task)
            navigationState.pendingRequest = nil
        }
    }
}

#Preview {
    ConventionalSpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil,
        navigationState: SpreadsNavigationState()
    )
}
