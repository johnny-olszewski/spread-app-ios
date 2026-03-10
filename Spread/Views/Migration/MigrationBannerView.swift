import SwiftUI

/// Banner shown at top of spread when there are tasks eligible for migration.
///
/// Displays a count of migratable tasks with quick actions to review individually
/// or migrate all at once. Only shows for tasks, not notes (per spec).
struct MigrationBannerView: View {

    // MARK: - Properties

    /// Number of eligible tasks.
    let eligibleTaskCount: Int

    /// Callback to migrate all eligible tasks.
    let onMigrateAll: () -> Void

    /// Callback to open the selection sheet for review.
    let onReview: () -> Void

    /// Callback to dismiss the banner.
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(eligibleTaskCount) task\(eligibleTaskCount == 1 ? "" : "s") can be migrated")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("From parent spreads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Review") {
                    onReview()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Migrate All") {
                    onMigrateAll()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBlue).opacity(0.1))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Previews

#Preview("Single Task") {
    VStack {
        MigrationBannerView(
            eligibleTaskCount: 1,
            onMigrateAll: {},
            onReview: {},
            onDismiss: {}
        )
        Spacer()
    }
}

#Preview("Multiple Tasks") {
    VStack {
        MigrationBannerView(
            eligibleTaskCount: 5,
            onMigrateAll: {},
            onReview: {},
            onDismiss: {}
        )
        Spacer()
    }
}
