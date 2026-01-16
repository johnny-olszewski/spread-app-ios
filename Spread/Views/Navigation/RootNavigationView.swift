import SwiftUI

/// Adaptive root navigation container for the app.
///
/// Switches between sidebar navigation (iPad) and tab-based navigation (iPhone)
/// based on the horizontal size class. Supports iPad multitasking modes
/// (Split View, Slide Over) by responding to size class changes.
///
/// The navigation structure includes:
/// - Spreads: Journal spread hierarchy
/// - Collections: Plain text pages outside spread navigation
/// - Settings: App preferences and mode selection
/// - Inbox: Badge/button in toolbar (opens sheet)
struct RootNavigationView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The journal manager for accessing spreads and inbox.
    let journalManager: JournalManager

    /// The dependency container for app-wide services.
    let container: DependencyContainer

    var body: some View {
        Group {
            switch NavigationLayoutType.forSizeClass(horizontalSizeClass) {
            case .sidebar:
                SidebarNavigationView(
                    journalManager: journalManager,
                    container: container
                )
            case .tabBar:
                TabNavigationView(
                    journalManager: journalManager,
                    container: container
                )
            }
        }
    }
}

#Preview("iPad - Sidebar") {
    RootNavigationView(
        journalManager: .previewInstance,
        container: try! .makeForPreview()
    )
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone - Tab Bar") {
    RootNavigationView(
        journalManager: .previewInstance,
        container: try! .makeForPreview()
    )
    .environment(\.horizontalSizeClass, .compact)
}
