import SwiftUI

/// Sidebar navigation for iPad (regular width).
///
/// Uses NavigationSplitView with a sidebar showing spreads, collections,
/// and settings. The detail view shows content for the selected item.
/// Inbox is accessible from the toolbar.
struct SidebarNavigationView: View {
    @State private var selectedItem: SidebarItem? = .spreads
    @State private var isInboxPresented = false

    /// The journal manager for accessing spreads and inbox.
    let journalManager: JournalManager

    /// The dependency container for app-wide services.
    let container: DependencyContainer

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Spread")
        } detail: {
            detailView
        }
        .sheet(isPresented: $isInboxPresented) {
            InboxPlaceholderView()
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                inboxButton
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
            DebugMenuView(container: container, journalManager: journalManager)
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
    SidebarNavigationView(
        journalManager: .previewInstance,
        container: try! .makeForPreview()
    )
}
