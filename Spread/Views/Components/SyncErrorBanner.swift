import SwiftUI

/// Non-tappable banner shown below the spread navigator strip when sync has failed.
///
/// Appears automatically when `SyncStatus` is `.error` and clears when sync
/// succeeds. Informs the user of the failure and directs them to pull to retry.
struct SyncErrorBanner: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("Last sync failed \u{00B7} Pull down to retry")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.orange.opacity(0.2))
                .frame(height: 1)
        }
        .accessibilityLabel("Last sync failed. Pull down to retry.")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SyncError.banner)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SyncErrorBanner()
        Spacer()
    }
}
