import SwiftUI

/// App-wide, non-tappable banner surfacing sync problems regardless of the active tab (SPRD-305).
///
/// Renders nothing while sync is healthy. Shows (in precedence order): offline state,
/// a failed last sync, or quarantined changes awaiting manual retry from Settings.
struct SyncStatusBanner: View {

    // MARK: - Model

    /// The banner's visible condition, in precedence order.
    private enum Presentation {
        case offline
        case error
        case quarantined(Int)

        var message: String {
            switch self {
            case .offline:
                "Offline \u{00B7} Changes will sync when you're back online"
            case .error:
                "Last sync failed \u{00B7} Retries automatically"
            case .quarantined(let count):
                "\(count == 1 ? "A change" : "\(count) changes") couldn't sync \u{00B7} Retry from Settings"
            }
        }

        var isWarning: Bool {
            switch self {
            case .offline: false
            case .error, .quarantined: true
            }
        }
    }

    // MARK: - Properties

    let status: SyncStatus
    let quarantinedCount: Int

    private var presentation: Presentation? {
        if case .offline = status { return .offline }
        if case .error = status { return .error }
        if quarantinedCount > 0 { return .quarantined(quarantinedCount) }
        return nil
    }

    // MARK: - Body

    var body: some View {
        if let presentation {
            banner(for: presentation)
        }
    }

    private func banner(for presentation: Presentation) -> some View {
        let tint: Color = presentation.isWarning ? .orange : .secondary
        return HStack(spacing: 8) {
            icon(for: presentation)
            Text(presentation.message)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(tint.opacity(0.2))
                .frame(height: 1)
        }
        .accessibilityLabel(presentation.message)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SyncError.banner)
    }

    @ViewBuilder
    private func icon(for presentation: Presentation) -> some View {
        switch presentation {
        case .offline:
            SpreadTheme.Icon.cloud.sized(SpreadTheme.IconSize.small)
                .iconTint(.secondary)
        case .error, .quarantined:
            SpreadTheme.Icon.cloudWarning.sized(SpreadTheme.IconSize.small)
                .iconTint(.orange)
        }
    }
}

// MARK: - Preview

#Preview("Error") {
    VStack(spacing: 0) {
        SyncStatusBanner(status: .error("Sync failed. Will retry."), quarantinedCount: 0)
        Spacer()
    }
}

#Preview("Offline") {
    VStack(spacing: 0) {
        SyncStatusBanner(status: .offline, quarantinedCount: 0)
        Spacer()
    }
}

#Preview("Quarantined") {
    VStack(spacing: 0) {
        SyncStatusBanner(status: .synced(.now), quarantinedCount: 2)
        Spacer()
    }
}

#Preview("Healthy (renders nothing)") {
    VStack(spacing: 0) {
        SyncStatusBanner(status: .synced(.now), quarantinedCount: 0)
        Spacer()
    }
}
