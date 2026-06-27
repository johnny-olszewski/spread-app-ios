import Foundation

/// Policy hooks for controlling sync behavior.
///
/// `DefaultSyncPolicy` is the sole conformance, used by all builds. The
/// protocol is retained as a dependency-injection seam for future test
/// substitution (per `CLAUDE.md` testability guidelines).
protocol SyncPolicy {
    /// Whether syncing is allowed at this time.
    func shouldAllowSync() -> Bool

    /// Whether sync should fail immediately for testing.
    func forceSyncFailure() -> Bool

    /// Optional forced syncing duration for testing UI states.
    func forceSyncingDuration() -> TimeInterval?
}

/// Default policy used in Release builds.
struct DefaultSyncPolicy: SyncPolicy {
    func shouldAllowSync() -> Bool { true }
    func forceSyncFailure() -> Bool { false }
    func forceSyncingDuration() -> TimeInterval? { nil }
}
