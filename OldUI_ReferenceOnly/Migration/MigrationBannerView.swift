//
//  MigrationBannerView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Banner shown at top of spread when there are tasks eligible for migration.
/// Shows count and provides quick actions.
struct MigrationBannerView: View {
    let eligibleTaskCount: Int
    let onMigrateAll: () -> Void
    let onReview: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text("\(eligibleTaskCount) task\(eligibleTaskCount == 1 ? "" : "s") can be migrated")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("From parent spreads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
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

            // Dismiss
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
