#if DEBUG
import Observation

/// Debug decorator that intercepts connectivity via `DebugSyncOverrides`.
///
/// Wraps a real `NetworkMonitoring` instance and overrides `isConnected`
/// to return `false` when `DebugSyncOverrides.shared.blockAllNetwork` is true.
/// Follows the same decorator pattern as `DebugAuthService`.
@Observable
@MainActor
final class DebugNetworkMonitor: NetworkMonitoring {

    // MARK: - Properties

    private let wrapped: any NetworkMonitoring

    /// Returns false when `blockAllNetwork` is true, otherwise delegates to wrapped monitor.
    var isConnected: Bool {
        if DebugSyncOverrides.shared.blockAllNetwork {
            return false
        }
        return wrapped.isConnected
    }

    /// Forwards connection change callbacks to/from the wrapped monitor.
    var onConnectionChange: ((Bool) -> Void)? {
        get { wrapped.onConnectionChange }
        set { wrapped.onConnectionChange = newValue }
    }

    // MARK: - Initialization

    /// Creates a debug network monitor wrapping another monitor.
    ///
    /// - Parameter wrapping: The underlying monitor to delegate to.
    init(wrapping monitor: any NetworkMonitoring) {
        self.wrapped = monitor
    }
}
#endif
