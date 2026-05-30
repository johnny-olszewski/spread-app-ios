import SwiftUI

/// Adaptive root navigation container for the app.
///
/// Uses a single `TabView` root for both iPhone and iPad and relies on
/// SwiftUI's adaptive tab presentation to show a tab bar on iPhone and a
/// sidebar-capable presentation on iPad.
struct RootNavigationView: View {
    let journalManager: JournalManager
    let authManager: AuthManager
    let dependencies: AppDependencies
    let syncEngine: SyncEngine?
    let appClock: AppClock
    let makeDebugMenuView: DebugMenuViewFactory?

    @State private var selectedTab: NavigationTab = .spreads
    @State private var isAuthPresented = false
    @State private var spreadsNavigationState = SpreadsNavigationState()
    @State private var spreadsCoordinator = SpreadsCoordinator()

    init(
        journalManager: JournalManager,
        authManager: AuthManager,
        dependencies: AppDependencies,
        syncEngine: SyncEngine? = nil,
        appClock: AppClock,
        makeDebugMenuView: DebugMenuViewFactory? = nil
    ) {
        self.journalManager = journalManager
        self.authManager = authManager
        self.dependencies = dependencies
        self.syncEngine = syncEngine
        self.appClock = appClock
        self.makeDebugMenuView = makeDebugMenuView
    }

    var body: some View {
        
        TabView(selection: $selectedTab) {
            ForEach(NavigationTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    tabContent(for: tab)
                }
            }
        }
        .tabViewStyle(.automatic)
        .sheet(isPresented: $isAuthPresented) {
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
        .onChange(of: syncEngine?.status) { _, newValue in
            guard case .synced = newValue else { return }
            Task { @MainActor in
                await journalManager.reload()
            }
        }
        .inspector(
            isPresented: Binding(
                get: { spreadsCoordinator.activeSheet != nil },
                set: { isPresented in
                    if !isPresented { spreadsCoordinator.activeSheet = nil }
                }
            )
        ) {
            if let destination = spreadsCoordinator.activeSheet {
                spreadsSheetContent(for: destination)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: NavigationTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .spreads:
                    SpreadsView(
                        coordinator: spreadsCoordinator,
                        journalManager: journalManager,
                        authManager: authManager,
                        syncEngine: syncEngine,
                        navigationState: spreadsNavigationState
                    )
                case .entries:
                    EntriesBrowserView(
                        journalManager: journalManager,
                        listRepository: dependencies.listRepository,
                        tagRepository: dependencies.tagRepository
                    ) { taskID, selection in
                        openTaskFromSearch(taskID: taskID, selection: selection)
                    }
                case .collections:
                    CollectionsListView(
                        collectionRepository: dependencies.collectionRepository,
                        syncEngine: syncEngine
                    )
                case .settings:
                    SettingsView(
                        journalManager: journalManager,
                        settingsRepository: dependencies.settingsRepository,
                        syncEngine: syncEngine
                    )
                case .debug:
                    debugMenuView
                }
            }
            .modifier(NonSpreadNavigationTitleModifier(tab: tab))
            .toolbar {
                if tab != .spreads {
                    ToolbarItem(placement: .primaryAction) {
                        AuthButton(isSignedIn: authManager.state.isSignedIn) {
                            isAuthPresented = true
                        }
                    }
                }
            }
        }
    }

    private func openTaskFromSearch(taskID: UUID, selection: DataModel.Spread?) {
        selectedTab = .spreads
        let resolvedSelection = selection ?? fallbackSearchSelection()
        spreadsNavigationState.pendingRequest = SpreadsNavigationRequest(
            selection: resolvedSelection,
            taskID: taskID
        )
    }

    private func fallbackSearchSelection() -> DataModel.Spread {
        journalManager.bestSpread(for: journalManager.today)
            ?? journalManager.spreads.first
            ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
    }

    // MARK: - Spreads Sheet Content

    private var spreadsCurrentSelection: DataModel.Spread {
        spreadsCoordinator.selectedSelection ?? journalManager.defaultNavigationSelection
    }

    private var spreadsCalendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    @ViewBuilder
    private func spreadsSheetContent(for destination: SpreadsCoordinator.SheetDestination) -> some View {
        switch destination {
        case .spreadCreation(let prefill):
            SpreadCreationSheet(
                journalManager: journalManager,
                firstWeekday: journalManager.firstWeekday,
                initialPeriod: prefill?.period,
                initialDate: prefill?.date,
                onSpreadCreated: { result in
                    spreadsCoordinator.finishSpreadCreation(
                        result,
                        currentSelection: spreadsCurrentSelection,
                        calendar: journalManager.calendar
                    )
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .spreadNameEdit(let spread):
            SpreadNameEditSheet(
                journalManager: journalManager,
                spread: spread,
                onSaved: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .spreadDateEdit(let spread):
            if spread.period == .multiday {
                SpreadCreationSheet(
                    journalManager: journalManager,
                    firstWeekday: journalManager.firstWeekday,
                    editingMultidaySpread: spread,
                    onSpreadDatesSaved: { updatedSpread in
                        spreadsCoordinator.finishSpreadDateEdit(updatedSpread)
                        Task { @MainActor in await syncEngine?.syncNow() }
                    }
                )
            } else {
                Color.clear
            }
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: spreadsCurrentSelection,
                onTaskCreated: { _ in
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: spreadsCurrentSelection,
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
        case .peekData(let data):
            SpreadPeekPanelView(
                data: data,
                calendar: spreadsCalendar,
                today: journalManager.today,
                onClose: { spreadsCoordinator.dismiss() },
                onNavigate: { destination in
                    spreadsCoordinator.dismiss()
                    spreadsCoordinator.selectSpread(destination)
                },
                onTaskTap: nil
            )
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
    }

    // MARK: - Debug

    @ViewBuilder
    private var debugMenuView: some View {
        if let view = makeDebugMenuView?(
            dependencies, journalManager, authManager, syncEngine, appClock
        ) {
            view
        } else {
            Text("Debug tools unavailable")
                .foregroundStyle(.secondary)
        }
    }
}

private struct NonSpreadNavigationTitleModifier: ViewModifier {
    let tab: NavigationTab

    @ViewBuilder
    func body(content: Content) -> some View {
        if tab == .spreads || tab == .entries {
            content
        } else {
            content.navigationTitle(tab.title)
        }
    }
}

#Preview("Regular Adaptive") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview(),
        appClock: .live()
    )
}

#Preview("Compact Tabs") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview(),
        appClock: .live()
    )
}
