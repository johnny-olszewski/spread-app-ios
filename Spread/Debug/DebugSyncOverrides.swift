#if DEBUG
import Foundation
import Observation

/// Debug-only runtime overrides for network behavior.
///
/// Allows testing offline states without relying on real network behavior.
/// Used by the Debug menu to simulate network unavailability.
@Observable
@MainActor
final class DebugSyncOverrides {

    // MARK: - Shared Instance

    /// The shared overrides instance used throughout the app.
    static let shared = DebugSyncOverrides()

    // MARK: - Network Overrides

    /// When true, forces NetworkMonitor to report offline and all requests fail.
    var blockAllNetwork = false

    // MARK: - Sync Overrides

    /// When true, forces sync operations to fail immediately.
    var forceSyncFailure = false

    /// When set, forces sync to remain in the syncing state for this duration.
    var forcedSyncingDuration: TimeInterval?

    // MARK: - Auth Overrides

    /// When set, forces sign-in to fail with this error before hitting Supabase.
    var forcedAuthError: ForcedAuthError?

    // MARK: - Reset

    /// Resets all overrides to default values.
    func reset() {
        blockAllNetwork = false
        forceSyncFailure = false
        forcedSyncingDuration = nil
        forcedAuthError = nil
    }
}
#endif
