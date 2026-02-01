#if DEBUG
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

    // MARK: - Reset

    /// Resets all overrides to default values.
    func reset() {
        blockAllNetwork = false
    }
}
#endif
