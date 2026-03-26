import SwiftUI

/// Tab-based navigation for iPhone (compact width).
///
/// Uses TabView with tabs for spreads, collections, and settings.
/// Inbox is accessible from the navigation bar in each tab.
struct TabNavigationView: View {
    @State private var selectedTab: NavigationTab = .spreads
    @State private var isInboxPresented = false
    @State private var isAuthPresented = false
    @State private var isOverduePresented = false

    /// The journal manager for accessing spreads and inbox.
    let journalManager: JournalManager

    /// The auth manager for handling authentication.
    let authManager: AuthManager

    /// The app dependencies for app-wide services.
    let dependencies: AppDependencies

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Optional factory for constructing the debug menu view.
    let makeDebugMenuView: DebugMenuViewFactory?

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(NavigationTab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .sheet(isPresented: $isInboxPresented) {
            InboxSheetView(journalManager: journalManager)
        }
        .sheet(isPresented: $isAuthPresented) {
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        }
        .sheet(isPresented: $isOverduePresented) {
            OverdueReviewSheet(
                journalManager: journalManager,
                syncEngine: syncEngine
            )
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: NavigationTab) -> some View {
        if tab == .spreads && journalManager.bujoMode == .traditional {
            // Traditional mode provides its own NavigationStack for drill-in.
            spreadsView
        } else {
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
                .navigationTitle(tab.title)
                .toolbar {
                    if let syncEngine {
                        ToolbarItem(placement: .navigationBarLeading) {
                            SyncStatusView(syncEngine: syncEngine)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 16) {
                            if tab == .spreads {
                                OverdueButton(overdueCount: journalManager.overdueTaskCount) {
                                    isOverduePresented = true
                                }
                            }
                            InboxButton(inboxCount: journalManager.inboxCount) {
                                isInboxPresented = true
                            }
                            AuthButton(isSignedIn: authManager.state.isSignedIn) {
                                isAuthPresented = true
                            }
                        }
                    }
                }
            }
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

    // MARK: - Spreads View

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
}

#Preview {
    TabNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview(),
        syncEngine: nil,
        makeDebugMenuView: nil
    )
}
