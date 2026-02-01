#if DEBUG
import SwiftUI

/// A debug overlay that displays the current AppEnvironment and DependencyContainer status.
///
/// Tap to expand/collapse detailed environment and dependency information.
/// Only available in DEBUG builds.
struct DebugEnvironmentOverlay: ViewModifier {
    let container: DependencyContainer?

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
        VStack(alignment: .leading, spacing: 8) {
            environmentSection
            if container != nil {
                Divider()
                dependenciesSection
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Environment")
            detailRow(label: "Current", value: environment.rawValue)
            detailRow(label: "Container", value: environment.containerName)
            detailRow(label: "In-Memory Only", value: environment.isStoredInMemoryOnly ? "Yes" : "No")
            detailRow(label: "Uses Mock Data", value: environment.usesMockData ? "Yes" : "No")
        }
    }

    @ViewBuilder
    private var dependenciesSection: some View {
        if let container {
            let info = container.debugSummary
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("Dependencies")
                detailRow(label: "Tasks", value: info.shortTypeName(for: info.taskRepositoryType))
                detailRow(label: "Spreads", value: info.shortTypeName(for: info.spreadRepositoryType))
                detailRow(label: "Events", value: info.shortTypeName(for: info.eventRepositoryType))
                detailRow(label: "Notes", value: info.shortTypeName(for: info.noteRepositoryType))
                detailRow(label: "Collections", value: info.shortTypeName(for: info.collectionRepositoryType))
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
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
        case .live:
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
    /// with tap-to-expand details including DependencyContainer status.
    ///
    /// - Parameter container: Optional dependency container to display status for.
    func debugEnvironmentOverlay(container: DependencyContainer? = nil) -> some View {
        modifier(DebugEnvironmentOverlay(container: container))
    }
}

#Preview("Without Container") {
    Text("App Content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .debugEnvironmentOverlay()
}

#Preview("With Container") {
    Text("App Content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .debugEnvironmentOverlay(container: try! .makeForPreview())
}
#endif
