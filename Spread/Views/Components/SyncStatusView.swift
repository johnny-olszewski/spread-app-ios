import SwiftUI
import struct Foundation.UUID

/// Compact sync status display for navigation toolbars.
struct SyncStatusView: View {
    @Bindable var syncEngine: SyncEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: syncEngine.status.systemImage)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text(syncEngine.status.displayText)
                    .font(.caption)
                    .lineLimit(1)
                if shouldShowLastSync, let lastSyncDate = syncEngine.lastSyncDate {
                    Text("Last sync \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if shouldShowLastSync, let lastSyncDate = syncEngine.lastSyncDate {
            return "\(syncEngine.status.displayText). Last sync \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))."
        }
        return syncEngine.status.displayText
    }

    private var shouldShowLastSync: Bool {
        if case .synced = syncEngine.status {
            return false
        }
        return true
    }
}

#Preview {
    let syncEngine = SyncEngine(
        client: nil,
        modelContainer: try! ModelContainerFactory.makeForTesting(),
        authManager: AuthManager(),
        networkMonitor: NetworkMonitor(),
        deviceId: UUID(),
        isSyncEnabled: false
    )
    return SyncStatusView(syncEngine: syncEngine)
        .padding()
}
