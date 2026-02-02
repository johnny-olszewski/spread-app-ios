import Foundation

/// Policy hooks for controlling sync behavior.
///
/// Production builds should use `DefaultSyncPolicy`. Debug builds can inject
/// policies to simulate failures or delays without changing core logic.
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
