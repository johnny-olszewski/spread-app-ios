#if DEBUG
import SwiftUI

/// A debug overlay that displays the current AppEnvironment.
///
/// Tap to expand/collapse detailed environment information.
/// Only available in DEBUG builds.
struct DebugEnvironmentOverlay: ViewModifier {
    @State private var isExpanded = false

    private var environment: AppEnvironment {
        AppEnvironment.current
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            debugBadge
                .padding(8)
        }
    }

    // MARK: - Subviews

    private var debugBadge: some View {
        VStack(alignment: .trailing, spacing: 4) {
            badgeButton

            if isExpanded {
                detailsCard
            }
        }
    }

    private var badgeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "ladybug.fill")
                    .font(.caption2)
                Text(environment.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: "Environment", value: environment.rawValue)
            detailRow(label: "Container", value: environment.containerName)
            detailRow(label: "In-Memory Only", value: environment.isStoredInMemoryOnly ? "Yes" : "No")
            detailRow(label: "Uses Mock Data", value: environment.usesMockData ? "Yes" : "No")
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }

    private var badgeColor: Color {
        switch environment {
        case .production:
            return .red
        case .development:
            return .blue
        case .preview:
            return .purple
        case .testing:
            return .orange
        }
    }
}

extension View {
    /// Adds a debug environment overlay to the view.
    ///
    /// Only available in DEBUG builds. Shows current `AppEnvironment`
    /// with tap-to-expand details.
    func debugEnvironmentOverlay() -> some View {
        modifier(DebugEnvironmentOverlay())
    }
}

#Preview("Development") {
    Text("App Content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .debugEnvironmentOverlay()
}
#endif
