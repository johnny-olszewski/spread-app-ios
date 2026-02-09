/// Test double for `NetworkMonitoring` with controllable connectivity.
///
/// Defaults to connected. Set `isConnected` to false to simulate offline.
@MainActor
final class MockNetworkMonitor: NetworkMonitoring {

    /// Whether the mock reports as connected.
    var isConnected: Bool = true

    /// Called when connectivity changes.
    var onConnectionChange: ((Bool) -> Void)?
}
