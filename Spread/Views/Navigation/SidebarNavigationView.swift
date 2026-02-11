import SwiftUI

/// Sidebar navigation for iPad (regular width).
///
/// Uses NavigationSplitView with a sidebar showing spreads, collections,
/// and settings. The detail view shows content for the selected item.
/// Inbox is accessible from the spreads toolbar (not the sidebar).
struct SidebarNavigationView: View {
    @State private var selectedItem: SidebarItem? = .spreads
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    /// The journal manager for accessing spreads and inbox.
    let journalManager: JournalManager

    /// The auth manager for handling authentication.
    let authManager: AuthManager

    /// The dependency container for app-wide services.
    let container: DependencyContainer

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Callback when environment switch completes and restart is needed.
    var onRestartRequired: (() -> Void)?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationTitle("Spread")
        } detail: {
            detailView
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedItem) {
            ForEach(SidebarItem.allCases) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.systemImage)
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .spreads:
            spreadsView
        case .collections:
            CollectionsPlaceholderView()
        case .settings:
            SettingsPlaceholderView()
        case .debug:
            debugMenuView
        case .none:
            Text("Select an item")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var debugMenuView: some View {
        if let debugView = DebugUIHooks.makeDebugMenuView?(
            container,
            journalManager,
            authManager,
            syncEngine,
            onRestartRequired
        ) {
            debugView
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
            TraditionalSpreadsPlaceholderView()
        }
    }
}

#Preview {
    SidebarNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        container: try! .makeForPreview(),
        syncEngine: nil
    )
}
