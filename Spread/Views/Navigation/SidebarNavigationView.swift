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
        #if DEBUG
        case .debug:
            DebugMenuView(container: container, journalManager: journalManager, authManager: authManager, syncEngine: syncEngine)
        #endif
        case .none:
            Text("Select an item")
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
        authManager: AuthManager(),
        container: try! .makeForPreview(),
        syncEngine: nil
    )
}
