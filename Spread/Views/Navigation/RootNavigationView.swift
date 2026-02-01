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

    /// The auth manager for handling authentication.
    let authManager: AuthManager

    /// The dependency container for app-wide services.
    let container: DependencyContainer

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Optional layout override for deterministic testing and previews.
    private let layoutOverride: NavigationLayoutType?

    /// Creates a root navigation view.
    ///
    /// - Parameters:
    ///   - journalManager: The journal manager for app data.
    ///   - authManager: The auth manager for authentication.
    ///   - container: The dependency container for app services.
    ///   - syncEngine: The sync engine (nil in previews/tests).
    ///   - layoutOverride: Optional layout override for tests/previews.
    init(
        journalManager: JournalManager,
        authManager: AuthManager,
        container: DependencyContainer,
        syncEngine: SyncEngine? = nil,
        layoutOverride: NavigationLayoutType? = nil
    ) {
        self.journalManager = journalManager
        self.authManager = authManager
        self.container = container
        self.syncEngine = syncEngine
        self.layoutOverride = layoutOverride
    }

    /// The resolved layout type for the current size class.
    ///
    /// Uses the override when provided to keep tests deterministic.
    var layoutType: NavigationLayoutType {
        layoutOverride ?? NavigationLayoutType.forSizeClass(horizontalSizeClass)
    }

    var body: some View {
        Group {
            switch layoutType {
            case .sidebar:
                SidebarNavigationView(
                    journalManager: journalManager,
                    authManager: authManager,
                    container: container,
                    syncEngine: syncEngine
                )
            case .tabBar:
                TabNavigationView(
                    journalManager: journalManager,
                    authManager: authManager,
                    container: container,
                    syncEngine: syncEngine
                )
            }
        }
    }
}

#Preview("iPad - Sidebar") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: AuthManager(),
        container: try! .makeForPreview()
    )
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone - Tab Bar") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: AuthManager(),
        container: try! .makeForPreview()
    )
    .environment(\.horizontalSizeClass, .compact)
}
