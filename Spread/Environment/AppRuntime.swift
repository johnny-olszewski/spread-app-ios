import SwiftUI

/// Closure that constructs the debug menu view, threaded through the view hierarchy.
typealias DebugMenuViewFactory = (
    AppDependencies,
    JournalManager,
    AuthManager,
    SyncEngine?,
    AppClock
) -> AnyView

/// Aggregates app-level services created for a running app runtime.
struct AppRuntime {
    let dependencies: AppDependencies
    let appClock: AppClock
    let journalManager: JournalManager
    let authManager: AuthManager
    let syncEngine: SyncEngine
    let authCoordinator: AuthLifecycleCoordinator

    /// Repository for persisting user settings changes.
    var settingsRepository: any SettingsRepository {
        dependencies.settingsRepository
    }

    /// Optional factory for constructing the debug menu view.
    ///
    /// Non-nil in debug/QA builds where `AppRuntimeConfiguration.debug()` provides the hook.
    /// Production builds leave this nil, hiding the debug tab entirely.
    let makeDebugMenuView: DebugMenuViewFactory?
}
