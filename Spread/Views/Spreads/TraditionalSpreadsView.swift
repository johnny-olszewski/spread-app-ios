import SwiftUI

enum TraditionalNavigationDestination: Hashable {
    case month(Date)
    case day(Date)
}

struct TraditionalSpreadsView: View {
    @Bindable var journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine?
    let navigationState: SpreadsNavigationState

    @State private var coordinator = SpreadsCoordinator()
    @State private var selectedSelection: SpreadHeaderNavigatorModel.Selection?
    @State private var recenterToken = 0

    private let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding = TodayMissingSpreadRecommendationProvider()

    private var defaultRootYearDate: Date {
        let calendar = journalManager.calendar
        let year = calendar.component(.year, from: journalManager.today)
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    private var navigatorModel: SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: journalManager.calendar,
            today: journalManager.today,
            spreads: journalManager.spreads,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
    }

    private var stripModel: SpreadTitleNavigatorModel {
        SpreadTitleNavigatorModel(
            headerModel: navigatorModel,
            overdueItems: journalManager.overdueTaskItems
        )
    }

    private var currentSelection: SpreadHeaderNavigatorModel.Selection {
        selectedSelection ?? .traditionalYear(defaultRootYearDate)
    }

    private var selectionBinding: Binding<SpreadHeaderNavigatorModel.Selection> {
        Binding(
            get: { currentSelection },
            set: { selectedSelection = $0 }
        )
    }

    private var stripItems: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    private var shellControls: SharedSpreadsShellControlConfiguration {
        SharedSpreadsShellControlConfiguration(
            showsTodayButton: true,
            onToday: navigateToToday,
            onCreateSpread: nil,
            onCreateTask: { coordinator.showTaskCreation() },
            onCreateNote: { coordinator.showNoteCreation() }
        )
    }

    private var traditionalService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: journalManager.calendar)
    }

    var body: some View {
        SharedSpreadsShellView(
            selection: selectionBinding,
            stripModel: stripModel,
            recenterToken: recenterToken,
            recommendationProvider: recommendationProvider,
            onRecommendedSpreadTapped: nil,
            authManager: authManager,
            onAuth: { coordinator.showAuth() },
            syncStatus: syncEngine?.status,
            controls: shellControls,
            items: stripItems
        ) { item in
            traditionalPage(for: item)
        }
        .sheet(item: $coordinator.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onAppear {
            if selectedSelection == nil {
                selectedSelection = .traditionalYear(defaultRootYearDate)
            }
            handlePendingNavigationRequest()
        }
        .onChange(of: navigationState.pendingRequest?.id) { _, _ in
            handlePendingNavigationRequest()
        }
    }

    private func navigateToToday() {
        let target = SpreadHeaderNavigatorModel.Selection.traditionalDay(
            Period.day.normalizeDate(journalManager.today, calendar: journalManager.calendar)
        )
        if target.stableID(calendar: journalManager.calendar) == currentSelection.stableID(calendar: journalManager.calendar) {
            recenterToken += 1
        } else {
            selectedSelection = target
        }
    }

    private func spread(for selection: SpreadHeaderNavigatorModel.Selection) -> DataModel.Spread {
        switch selection {
        case .traditionalYear(let yearDate):
            return DataModel.Spread(period: .year, date: yearDate, calendar: journalManager.calendar)
        case .traditionalMonth(let monthDate):
            return DataModel.Spread(period: .month, date: monthDate, calendar: journalManager.calendar)
        case .traditionalDay(let dayDate):
            return DataModel.Spread(period: .day, date: dayDate, calendar: journalManager.calendar)
        case .conventional:
            return DataModel.Spread(period: .year, date: defaultRootYearDate, calendar: journalManager.calendar)
        }
    }

    private func spreadDataModel(for selection: SpreadHeaderNavigatorModel.Selection) -> SpreadDataModel {
        let spread = spread(for: selection)
        return traditionalService.virtualSpreadDataModel(
            period: spread.period,
            date: spread.date,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
    }

    @ViewBuilder
    private func traditionalPage(for item: SpreadTitleNavigatorModel.Item) -> some View {
        switch item.selection {
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            let spread = spread(for: item.selection)
            SpreadSurfaceView(
                spread: spread,
                spreadDataModel: spreadDataModel(for: item.selection),
                calendar: journalManager.calendar,
                today: journalManager.today,
                headerNavigatorModel: navigatorModel,
                entryListConfiguration: EntryListConfiguration(
                    groupingStyle: .flat,
                    showsMigrationHistory: false
                ),
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
                onRefresh: {
                    guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
                    await engine.syncNow()
                },
                syncStatus: syncEngine?.status,
                onSelectSpread: { selection in
                    switch selection {
                    case .traditionalYear, .traditionalMonth, .traditionalDay:
                        selectedSelection = selection
                    case .conventional:
                        break
                    }
                }
            )
        case .conventional:
            Color.clear
        }
    }

    @ViewBuilder
    private func sheetContent(for destination: SpreadsCoordinator.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation:
            Color.clear
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: spread(for: currentSelection),
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: spread(for: currentSelection),
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

    private func monthAccessory(for spread: DataModel.Spread) -> AnyView? {
        guard spread.period == .month else { return nil }
        return AnyView(
            SpreadMonthCalendarView(
                monthDate: spread.date,
                mode: .traditional,
                journalManager: journalManager
            )
        )
    }

    private func handlePendingNavigationRequest() {
        guard let request = navigationState.pendingRequest else { return }

        switch request.selection {
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            selectedSelection = request.selection
        case .conventional:
            return
        }

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
