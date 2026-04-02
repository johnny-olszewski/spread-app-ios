import SwiftUI

/// Interactive sync status icon for navigation toolbars.
///
/// Displays an SF Symbol whose icon, tint, and animation reflect the current
/// sync state. Tapping shows a short tooltip and triggers a sync where
/// appropriate. The tooltip auto-dismisses after 2.5 seconds or on tap outside.
///
/// State mapping:
/// - `.idle` → white icon, tap shows "Not yet synced", triggers sync
/// - `.syncing` → white icon, rotating counterclockwise, tap shows "Syncing…"
/// - `.synced` → white icon, tap shows last-synced time, triggers sync
/// - `.error` → yellow error icon, tap shows error message, triggers sync retry
/// - `.offline` → grey icon, tap shows "Offline"
/// - `.localOnly` → grey icon, tap shows "Local only"
struct SyncStatusView: View {

    @Bindable var syncEngine: SyncEngine

    @State private var isTooltipVisible = false
    @State private var isSpinning = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Button {
            handleTap()
        } label: {
            Image(systemName: syncEngine.status.iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .rotationEffect(.degrees(isSpinning ? -360 : 0))
                .animation(
                    isSpinning
                        ? .linear(duration: 1.2).repeatForever(autoreverses: false)
                        : .linear(duration: 0),
                    value: isSpinning
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isTooltipVisible) {
            Text(syncEngine.status.tooltipMessage)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .fixedSize()
                .presentationCompactAdaptation(.popover)
        }
        .onChange(of: syncEngine.status.isRotating, initial: true) { _, rotating in
            isSpinning = rotating
        }
        .onDisappear {
            dismissTask?.cancel()
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("syncStatus.icon")
    }

    // MARK: - Private

    private var iconColor: Color {
        switch syncEngine.status.iconTint {
        case .primary: .primary
        case .secondary: .secondary
        case .warning: .yellow
        }
    }

    private var accessibilityLabel: String {
        if let lastSyncDate = syncEngine.lastSyncDate {
            return "\(syncEngine.status.tooltipMessage). Last sync \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))."
        }
        return syncEngine.status.tooltipMessage
    }

    private func handleTap() {
        isTooltipVisible = true
        scheduleDismiss()
        if syncEngine.status.shouldTriggerSync {
            Task { await syncEngine.syncNow() }
        }
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            isTooltipVisible = false
        }
    }
}

// MARK: - Previews

#Preview("Idle") {
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

#Preview("Syncing") {
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
        .onAppear { syncEngine.status = .syncing }
}

#Preview("Error") {
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
        .onAppear { syncEngine.status = .error("Sync failed. Will retry.") }
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
