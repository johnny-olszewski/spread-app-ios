/// Build-config selector for the network monitor implementation.
///
/// Debug builds use `DebugNetworkMonitor` which supports forced offline
/// via `DebugSyncOverrides.blockAllNetwork`. Release builds use the
/// plain `NetworkMonitor` backed by `NWPathMonitor`.
#if DEBUG
typealias AppNetworkMonitor = DebugNetworkMonitor
#else
typealias AppNetworkMonitor = NetworkMonitor
#endif
