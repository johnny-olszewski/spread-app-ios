import SwiftUI

/// Banner shown at top of spread when there are tasks eligible for migration.
///
/// Displays a count of migratable tasks with a single review action.
/// Only shows for tasks, not notes (per spec).
struct MigrationBannerView: View {

    // MARK: - Properties

    /// Number of eligible tasks.
    let eligibleTaskCount: Int

    /// Callback to open the selection sheet for review.
    let onReview: () -> Void

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

                Text("Review tasks that can move into this spread")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Review") {
                onReview()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
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
            onReview: {}
        )
        Spacer()
    }
}

#Preview("Multiple Tasks") {
    VStack {
        MigrationBannerView(
            eligibleTaskCount: 5,
            onReview: {}
        )
        Spacer()
    }
}
