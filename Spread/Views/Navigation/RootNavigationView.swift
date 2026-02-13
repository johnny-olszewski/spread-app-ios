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

    /// The app dependencies for app-wide services.
    let dependencies: AppDependencies

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Callback when environment switch completes and restart is needed.
    var onRestartRequired: (() -> Void)?

    /// Optional factory for constructing the debug menu view.
    let makeDebugMenuView: DebugMenuViewFactory?

    /// Optional layout override for deterministic testing and previews.
    private let layoutOverride: NavigationLayoutType?

    /// Creates a root navigation view.
    ///
    /// - Parameters:
    ///   - journalManager: The journal manager for app data.
    ///   - authManager: The auth manager for authentication.
    ///   - dependencies: The app dependencies for app services.
    ///   - syncEngine: The sync engine (nil in previews/tests).
    ///   - onRestartRequired: Callback for soft restart after environment switch.
    ///   - makeDebugMenuView: Optional factory for the debug menu view.
    ///   - layoutOverride: Optional layout override for tests/previews.
    init(
        journalManager: JournalManager,
        authManager: AuthManager,
        dependencies: AppDependencies,
        syncEngine: SyncEngine? = nil,
        onRestartRequired: (() -> Void)? = nil,
        makeDebugMenuView: DebugMenuViewFactory? = nil,
        layoutOverride: NavigationLayoutType? = nil
    ) {
        self.journalManager = journalManager
        self.authManager = authManager
        self.dependencies = dependencies
        self.syncEngine = syncEngine
        self.onRestartRequired = onRestartRequired
        self.makeDebugMenuView = makeDebugMenuView
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
                    dependencies: dependencies,
                    syncEngine: syncEngine,
                    onRestartRequired: onRestartRequired,
                    makeDebugMenuView: makeDebugMenuView
                )
            case .tabBar:
                TabNavigationView(
                    journalManager: journalManager,
                    authManager: authManager,
                    dependencies: dependencies,
                    syncEngine: syncEngine,
                    onRestartRequired: onRestartRequired,
                    makeDebugMenuView: makeDebugMenuView
                )
            }
        }
        .onChange(of: syncEngine?.status) { _, newValue in
            guard case .synced = newValue else { return }
            Task { await journalManager.reload() }
        }
    }
}

#Preview("iPad - Sidebar") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview()
    )
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone - Tab Bar") {
    RootNavigationView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        dependencies: try! .makeForPreview()
    )
    .environment(\.horizontalSizeClass, .compact)
}
