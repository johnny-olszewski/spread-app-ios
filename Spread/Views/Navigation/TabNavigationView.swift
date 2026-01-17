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
            InboxPlaceholderView()
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
                    DebugMenuView(container: container)
                #endif
                }
            }
            .navigationTitle(tab.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    inboxButton
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

    // MARK: - Inbox Button

    private var inboxButton: some View {
        Button {
            isInboxPresented = true
        } label: {
            inboxButtonLabel
        }
        .accessibilityLabel("Inbox")
    }

    @ViewBuilder
    private var inboxButtonLabel: some View {
        let count = journalManager.inboxCount
        if count > 0 {
            Image(systemName: "tray.full")
                .overlay(alignment: .topTrailing) {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                        .offset(x: 8, y: -8)
                }
        } else {
            Image(systemName: "tray")
        }
    }
}

#Preview {
    TabNavigationView(
        journalManager: .previewInstance,
        container: try! .makeForPreview()
    )
}
