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
    let makeDebugMenuView: DebugMenuViewFactory?

    @State private var selectedTab: NavigationTab = .spreads
    @State private var isAuthPresented = false
    @State private var spreadsNavigationState = SpreadsNavigationState()

    init(
        journalManager: JournalManager,
        authManager: AuthManager,
        dependencies: AppDependencies,
        syncEngine: SyncEngine? = nil,
        makeDebugMenuView: DebugMenuViewFactory? = nil
    ) {
        self.journalManager = journalManager
        self.authManager = authManager
        self.dependencies = dependencies
        self.syncEngine = syncEngine
        self.makeDebugMenuView = makeDebugMenuView
    }

    var body: some View {
        rootTabView
            .tabViewStyle(.sidebarAdaptable)
            .sheet(isPresented: $isAuthPresented) {
                AuthEntrySheet(authManager: authManager, isBlocking: false)
            }
            .onChange(of: syncEngine?.status) { _, newValue in
                guard case .synced = newValue else { return }
                Task { @MainActor in
                    await journalManager.reload()
                }
            }
    }

    private var rootTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(NavigationTab.allCases) { tab in
                if tab == .search {
                    Tab(tab.title, systemImage: tab.systemImage, value: tab, role: .search) {
                        tabContent(for: tab)
                    }
                } else {
                    Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                        tabContent(for: tab)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: NavigationTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .spreads:
                    spreadsView
                case .search:
                    TaskSearchView(
                        journalManager: journalManager,
                        isActive: selectedTab == .search
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

    private var spreadsView: some View {
        SpreadsView(
            journalManager: journalManager,
            authManager: authManager,
            syncEngine: syncEngine,
            navigationState: spreadsNavigationState
        )
    }

    private func openTaskFromSearch(taskID: UUID, selection: SpreadHeaderNavigatorModel.Selection?) {
        selectedTab = .spreads
        if let selection {
            spreadsNavigationState.pendingRequest = SpreadsNavigationRequest(
                selection: selection,
                taskID: taskID
            )
        } else {
            let fallbackSelection = fallbackSearchSelection()
            spreadsNavigationState.pendingRequest = SpreadsNavigationRequest(
                selection: fallbackSelection,
                taskID: taskID
            )
        }
    }

    private func fallbackSearchSelection() -> SpreadHeaderNavigatorModel.Selection {
        switch journalManager.bujoMode {
        case .conventional:
            let organizer = SpreadHierarchyOrganizer(
                spreads: journalManager.spreads,
                calendar: journalManager.calendar
            )
            let spread = organizer.initialSelection(for: journalManager.today)
                ?? journalManager.spreads.first
                ?? DataModel.Spread(period: .year, date: journalManager.today, calendar: journalManager.calendar)
            return .conventional(spread)
        case .traditional:
            return .traditionalYear(
                Period.year.normalizeDate(journalManager.today, calendar: journalManager.calendar)
            )
        }
    }

    @ViewBuilder
    private var debugMenuView: some View {
        if let view = makeDebugMenuView?(
            dependencies, journalManager, authManager, syncEngine
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
        if tab == .spreads {
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
        dependencies: try! .makeForPreview()
    )
}

#Preview("Compact Tabs") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview()
    )
}
