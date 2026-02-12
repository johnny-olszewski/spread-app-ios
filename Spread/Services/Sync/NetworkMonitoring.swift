/// Abstraction for network connectivity monitoring.
///
/// Provides observable connectivity state and change notifications.
/// Production builds use `NetworkMonitor` (NWPathMonitor-backed).
/// Debug builds use `DebugNetworkMonitor` which supports forced offline mode.
@MainActor
protocol NetworkMonitoring: AnyObject, Sendable {
    /// Whether the device currently has network connectivity.
    var isConnected: Bool { get }

    /// Called when connectivity changes.
    var onConnectionChange: ((Bool) -> Void)? { get set }
}
