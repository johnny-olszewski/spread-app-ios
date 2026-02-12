import Foundation
import SwiftUI

/// Icon-only sync status display for navigation toolbars.
///
/// Shows an SF Symbol representing the current sync state.
/// Full status text is available via the accessibility label for VoiceOver.
struct SyncStatusView: View {
    @Bindable var syncEngine: SyncEngine

    var body: some View {
        Image(systemName: syncEngine.status.systemImage)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconForegroundStyle)
            .accessibilityLabel(accessibilityLabel)
    }

    private var iconForegroundStyle: some ShapeStyle {
        syncEngine.status.isBackupUnavailable ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    private var accessibilityLabel: String {
        if let lastSyncDate = syncEngine.lastSyncDate {
            return "\(syncEngine.status.displayText). Last sync \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))."
        }
        return syncEngine.status.displayText
    }
}

#Preview("Local Only") {
    let syncEngine = SyncEngine(
        client: nil,
        modelContainer: try! ModelContainerFactory.makeInMemory(),
        authManager: .makeForPreview(),
        networkMonitor: NetworkMonitor(),
        deviceId: UUID(),
        isSyncEnabled: false
    )
    SyncStatusView(syncEngine: syncEngine)
        .padding()
}
