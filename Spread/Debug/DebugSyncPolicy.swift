#if DEBUG
import Foundation

/// Debug-only sync policy with mutable overrides.
///
/// Owns `forceSyncFailure`, `forcedSyncingDuration`, and `isSyncDisabled`
/// state directly, allowing the debug menu to toggle sync behavior
/// without a singleton.
@MainActor
final class DebugSyncPolicy: SyncPolicy {

    /// When true, blocks both auto and manual sync triggers.
    var isSyncDisabled = false

    /// When true, forces sync operations to fail immediately.
    var isForceSyncFailure = false

    /// When set, forces sync to remain in the syncing state for this duration.
    var forcedSyncingDuration: TimeInterval?

    func shouldAllowSync() -> Bool {
        !isSyncDisabled
    }

    func forceSyncFailure() -> Bool {
        isForceSyncFailure
    }

    func forceSyncingDuration() -> TimeInterval? {
        forcedSyncingDuration
    }

    /// Resets all overrides to defaults.
    func resetAll() {
        isSyncDisabled = false
        isForceSyncFailure = false
        forcedSyncingDuration = nil
    }
}
#endif
