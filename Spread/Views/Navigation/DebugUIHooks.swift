import SwiftUI

/// Debug-only UI hooks for injecting the Debug menu without conditional compilation
/// in production view code.
enum DebugUIHooks {
    static var makeDebugMenuView: ((
        DependencyContainer,
        JournalManager,
        AuthManager,
        SyncEngine?,
        (() -> Void)?
    ) -> AnyView)?

    static var isEnabled: Bool {
        makeDebugMenuView != nil
    }
}
