import SwiftUI

/// A toolbar button that communicates sync state using `SpreadTheme.Icon`.
///
/// Visual states:
/// - **Syncing**: `.arrowsClockwise` with continuous rotation animation (driven manually via
///   `.rotationEffect` + `repeatForever`, since Phosphor icons are plain images and don't
///   support SF Symbol's `.symbolEffect(.rotate)`).
/// - **Idle / synced / offline**: `.arrowsClockwise`, static.
/// - **Error**: `.cloudWarning` in orange.
/// - **Local only**: hidden.
///
/// Tapping triggers a manual sync when `status.shouldTriggerSync`.
struct SyncIconButton: View {
    let status: SyncStatus
    let outboxCount: Int
    var onSyncNow: (() -> Void)? = nil

    @State private var rotationAngle: Angle = .zero

    private var isSpinning: Bool {
        if case .syncing = status { return true }
        return false
    }

    private var icon: SpreadTheme.Icon {
        if case .error = status {
            return .cloudWarning
        }
        return .arrowsClockwise
    }

    private var iconColor: Color {
        switch status {
        case .syncing, .synced:
            return SpreadTheme.Accent.primary
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
                icon.sized(SpreadTheme.IconSize.medium)
                    .iconTint(iconColor)
                    .rotationEffect(rotationAngle)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(status.shouldTriggerSync ? "Tap to sync now" : "")
            .onChange(of: isSpinning, initial: true) { _, isSpinning in
                if isSpinning {
                    withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                        rotationAngle = .degrees(360)
                    }
                } else {
                    withAnimation(.linear(duration: 0)) {
                        rotationAngle = .zero
                    }
                }
            }
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
