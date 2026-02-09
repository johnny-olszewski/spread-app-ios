#if DEBUG
import Observation

/// Debug decorator that intercepts connectivity with a local toggle.
///
/// Wraps a real `NetworkMonitoring` instance and overrides `isConnected`
/// to return `false` when `blockAllNetwork` is true.
/// Follows the same decorator pattern as `DebugAuthService`.
@Observable
@MainActor
final class DebugNetworkMonitor: NetworkMonitoring {

    // MARK: - Properties

    private let wrapped: any NetworkMonitoring

    /// When true, forces `isConnected` to return false regardless of real connectivity.
    var blockAllNetwork = false

    /// Returns false when `blockAllNetwork` is true, otherwise delegates to wrapped monitor.
    var isConnected: Bool {
        if blockAllNetwork {
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

    /// Creates a debug network monitor with its own internal `NetworkMonitor`.
    init() {
        self.wrapped = NetworkMonitor()
    }

    /// Creates a debug network monitor wrapping another monitor.
    ///
    /// - Parameter wrapping: The underlying monitor to delegate to.
    init(wrapping monitor: any NetworkMonitoring) {
        self.wrapped = monitor
    }
}
#endif
