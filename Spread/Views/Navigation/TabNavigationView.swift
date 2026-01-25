import SwiftUI

/// Tab-based navigation for iPhone (compact width).
///
/// Uses TabView with tabs for spreads, collections, and settings.
/// Inbox is accessible from the navigation bar in each tab.
struct TabNavigationView: View {
    @State private var selectedTab: NavigationTab = .spreads
    @State private var isInboxPresented = false

    /// The journal manager for accessing spreads and inbox.
    let journalManager: JournalManager

    /// The dependency container for app-wide services.
    let container: DependencyContainer

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
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: NavigationTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .spreads:
                    spreadsView
                case .collections:
                    CollectionsPlaceholderView()
                case .settings:
                    SettingsPlaceholderView()
                #if DEBUG
                case .debug:
                    DebugMenuView(container: container, journalManager: journalManager)
                #endif
                }
            }
            .navigationTitle(tab.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InboxButton(inboxCount: journalManager.inboxCount) {
                        isInboxPresented = true
                    }
                }
            }
        }
    }

    // MARK: - Spreads View

    @ViewBuilder
    private var spreadsView: some View {
        switch journalManager.bujoMode {
        case .conventional:
            ConventionalSpreadsView(journalManager: journalManager)
        case .traditional:
            TraditionalSpreadsPlaceholderView()
        }
    }
}

#Preview {
    TabNavigationView(
        journalManager: .previewInstance,
        container: try! .makeForPreview()
    )
}
