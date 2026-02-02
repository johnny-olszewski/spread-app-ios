import SwiftUI
import struct Foundation.UUID

/// Non-blocking status banner showing sync state in the main content area.
///
/// Displays the current sync status text and optional last sync date.
/// Hidden when the sync status is `.synced` or `.idle` to avoid clutter.
struct SyncStatusBanner: View {
    @Bindable var syncEngine: SyncEngine

    var body: some View {
        if shouldShow {
            HStack(spacing: 6) {
                Image(systemName: syncEngine.status.systemImage)
                    .font(.caption2)
                Text(syncEngine.status.displayText)
                    .font(.caption)
                if let lastSyncDate = syncEngine.lastSyncDate {
                    Text("· \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }

    private var shouldShow: Bool {
        switch syncEngine.status {
        case .synced, .idle:
            false
        default:
            true
        }
    }
}

#Preview("Offline") {
    let syncEngine = SyncEngine(
        client: nil,
        modelContainer: try! ModelContainerFactory.makeForTesting(),
        authManager: AuthManager(),
        networkMonitor: NetworkMonitor(),
        deviceId: UUID(),
        isSyncEnabled: false
    )
    return SyncStatusBanner(syncEngine: syncEngine)
}
