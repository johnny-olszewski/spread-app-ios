import SwiftUI

/// Root navigation container for the app.
///
/// Uses a plain `TabView` (`.tabViewStyle(.automatic)`) with one tab per top-level
/// `Content` destination. Each tab content view owns its own `NavigationStack` internally.
/// Destination-specific
/// navigation state is scoped to its own tab — most notably `SpreadsTabView`, which owns
/// all Spreads-specific state (selection, pager position, year, sheet/alert presentation)
/// so it survives size class transitions without being lifted to the root.
///
/// `RootNavigationView` retains only the active tab selection and the shared
/// `spreadsNavigationState`, used to route cross-tab navigation requests — e.g. opening
/// a task detail from a search result while on the Entries tab.
struct RootNavigationView: View {

    let journalManager: JournalManager
    let authManager: AuthManager
    let dependencies: AppDependencies
    let syncEngine: SyncEngine?
    let appClock: AppClock
    let makeDebugMenuView: DebugMenuViewFactory?

    // MARK: - Root-owned Navigation State

    @State private var selectedTab: Content = .spreads
    @State private var spreadsNavigationState = SpreadsNavigationState()

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

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Content.allCases) { content in
                Tab(value: content) {
                    tabContent(for: content)
                } label: {
                    Label {
                        Text(content.title)
                    } icon: {
                        content.icon.tabBarImage(size: SpreadTheme.IconSize.medium)
                    }
                }
            }
        }
        .tabViewStyle(.automatic)
        .onChange(of: syncEngine?.status) { _, newValue in
            guard case .synced = newValue else { return }
            Task { @MainActor in await journalManager.reload() }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for content: Content) -> some View {
        switch content {
        case .spreads:
            SpreadsTabView(
                journalManager: journalManager,
                authManager: authManager,
                syncEngine: syncEngine,
                spreadsNavigationState: spreadsNavigationState
            )
        case .entries:
            entriesBrowserView
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

    /// Extracted to a separate property to help the type-checker with the trailing closure.
    private var entriesBrowserView: some View {
        EntriesBrowserView(
            journalManager: journalManager,
            listRepository: dependencies.listRepository,
            tagRepository: dependencies.tagRepository
        ) { taskID, selection in
            openTaskFromSearch(taskID: taskID, selection: selection)
        }
    }

    // MARK: - Cross-tab Navigation

    /// Routes a search-result tap from another tab to the Spreads tab: resolves the
    /// target spread, switches `selectedTab`, and populates
    /// `spreadsNavigationState.pendingRequest` — which `SpreadsTabView` observes to
    /// select the spread, hide its content column, and open the task detail.
    private func openTaskFromSearch(taskID: UUID, selection: DataModel.Spread?) {
        let resolvedSelection = selection ?? fallbackSearchSelection()
        selectedTab = .spreads
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

// MARK: - Preview

#Preview("Root navigation") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview(),
        appClock: .live()
    )
}
