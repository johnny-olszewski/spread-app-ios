/// Factory for creating the app's network monitor.
///
/// Debug builds can override `make` via debug hooks to provide
/// a controllable network monitor.
enum NetworkMonitorFactory {
    static var make: () -> any NetworkMonitoring = { NetworkMonitor() }
}
