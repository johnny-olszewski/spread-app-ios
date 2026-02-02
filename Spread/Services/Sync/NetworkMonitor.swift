import Foundation
import Network
import Observation
import os

/// Monitors network connectivity using NWPathMonitor.
///
/// Provides observable `isConnected` state for gating sync operations.
/// The sync engine checks connectivity before attempting push/pull.
///
/// In DEBUG builds, connectivity can be overridden via `DebugSyncOverrides.blockAllNetwork`.
@Observable
@MainActor
final class NetworkMonitor {

    // MARK: - Properties

    /// Whether the device currently has network connectivity.
    ///
    /// In DEBUG builds, this returns false when `DebugSyncOverrides.blockAllNetwork` is true.
    var isConnected: Bool {
        #if DEBUG
        if DebugSyncOverrides.shared.blockAllNetwork {
            return false
        }
        #endif
        return actuallyConnected
    }

    /// The actual network connectivity state from NWPathMonitor.
    private var actuallyConnected = true

    /// The current connection type.
    private(set) var connectionType: ConnectionType = .unknown

    /// Called when connectivity changes.
    var onConnectionChange: ((Bool) -> Void)?

    /// The types of network connection available.
    enum ConnectionType: String, Sendable {
        case wifi
        case cellular
        case wired
        case unknown
    }

    // MARK: - Private

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "dev.johnnyo.Spread.networkMonitor")
    private let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "NetworkMonitor")

    // MARK: - Initialization

    /// Creates and starts a network monitor.
    init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    /// Starts monitoring network path changes.
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.actuallyConnected
                self.actuallyConnected = path.status == .satisfied
                self.connectionType = self.resolveConnectionType(path)

                if self.actuallyConnected != wasConnected {
                    self.logger.info(
                        "Network status changed: \(self.actuallyConnected ? "connected" : "disconnected") (\(self.connectionType.rawValue))"
                    )
                    self.onConnectionChange?(self.isConnected)
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Stops monitoring network path changes.
    func stopMonitoring() {
        monitor.cancel()
    }

    // MARK: - Private

    private nonisolated func resolveConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .unknown
    }
}
