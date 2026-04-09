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
    @State private var isInboxPresented = false
    @State private var isAuthPresented = false

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
            .sheet(isPresented: $isInboxPresented) {
                InboxSheetView(journalManager: journalManager)
            }
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
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    tabContent(for: tab)
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
                        InboxButton(inboxCount: journalManager.inboxCount) {
                            isInboxPresented = true
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        AuthButton(isSignedIn: authManager.state.isSignedIn) {
                            isAuthPresented = true
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var spreadsView: some View {
        switch journalManager.bujoMode {
        case .conventional:
            ConventionalSpreadsView(
                journalManager: journalManager,
                authManager: authManager,
                syncEngine: syncEngine
            )
        case .traditional:
            TraditionalSpreadsView(
                journalManager: journalManager,
                authManager: authManager,
                syncEngine: syncEngine
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
