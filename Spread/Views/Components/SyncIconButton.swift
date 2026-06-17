import SwiftUI

/// A toolbar button that communicates sync state using SF Symbols.
///
/// Visual states:
/// - **Syncing**: `arrow.triangle.2.circlepath` with continuous rotation animation.
/// - **Idle / synced / offline**: `arrow.triangle.2.circlepath`, static.
/// - **Error**: `exclamationmark.arrow.triangle.2.circlepath` in orange.
/// - **Local only**: hidden.
///
/// Tapping triggers a manual sync when `status.shouldTriggerSync`.
struct SyncIconButton: View {
    let status: SyncStatus
    let outboxCount: Int
    var onSyncNow: (() -> Void)? = nil

    private var isSpinning: Bool {
        if case .syncing = status { return true }
        return false
    }

    private var symbolName: String {
        if case .error = status {
            return "exclamationmark.arrow.triangle.2.circlepath"
        }
        return "arrow.triangle.2.circlepath"
    }

    private var iconColor: Color {
        switch status {
        case .syncing, .synced:
            return SpreadTheme.Accent.today
        case .idle where outboxCount > 0:
            return .secondary.opacity(0.7)
        case .idle:
            return .secondary
        case .error:
            return .orange
        case .offline:
            return .secondary.opacity(0.4)
        case .localOnly:
            return .clear
        }
    }

    var body: some View {
        if case .localOnly = status {
            EmptyView()
        } else {
            Button(action: handleTap) {
                Image(systemName: symbolName)
                    .font(.system(size: SpreadTheme.IconSize.medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.rotate, options: .repeating.speed(1.0), isActive: isSpinning)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(status.shouldTriggerSync ? "Tap to sync now" : "")
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .idle where outboxCount > 0:
            return "\(outboxCount) changes pending sync"
        case .idle:
            return "Not yet synced"
        case .syncing:
            return outboxCount > 0 ? "Syncing, \(outboxCount) changes remaining" : "Syncing"
        case .synced(let date):
            return "Synced \(date.formatted(.relative(presentation: .named)))"
        case .error(let message):
            return "Sync error: \(message)"
        case .offline:
            return "Offline, sync paused"
        case .localOnly:
            return "Local only"
        }
    }

    private func handleTap() {
        guard status.shouldTriggerSync else { return }
        onSyncNow?()
    }
}

// MARK: - Preview

#Preview("Synced") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SyncIconButton(status: .synced(Date()), outboxCount: 0)
                }
            }
    }
}

#Preview("Syncing") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SyncIconButton(status: .syncing, outboxCount: 2)
                }
            }
    }
}

#Preview("Error") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SyncIconButton(status: .error("Server unreachable"), outboxCount: 0)
                }
            }
    }
}

#Preview("Offline") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SyncIconButton(status: .offline, outboxCount: 0)
                }
            }
    }
}
