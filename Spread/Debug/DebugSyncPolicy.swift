#if DEBUG
import Foundation

/// Debug-only sync policy backed by `DebugSyncOverrides`.
struct DebugSyncPolicy: SyncPolicy {
    func shouldAllowSync() -> Bool {
        true
    }

    func forceSyncFailure() -> Bool {
        DebugSyncOverrides.shared.forceSyncFailure
    }

    func forceSyncingDuration() -> TimeInterval? {
        DebugSyncOverrides.shared.forcedSyncingDuration
    }
}
#endif
