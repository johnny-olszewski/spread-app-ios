import SwiftUI

/// Closure that constructs the debug menu view, threaded through the view hierarchy.
typealias DebugMenuViewFactory = (
    DependencyContainer,
    JournalManager,
    AuthManager,
    SyncEngine?,
    (() -> Void)?
) -> AnyView

/// Aggregates app-level services created for a running session.
struct AppSession {
    let container: DependencyContainer
    let journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine
    let coordinator: AuthLifecycleCoordinator

    /// Optional factory for constructing the debug menu view.
    ///
    /// Non-nil in debug/QA builds where `SessionConfiguration.debug()` provides the hook.
    /// Production builds leave this nil, hiding the debug tab entirely.
    let makeDebugMenuView: DebugMenuViewFactory?
}
