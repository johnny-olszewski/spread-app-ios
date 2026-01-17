#if DEBUG
import SwiftUI

/// Debug menu for inspecting environment, container, and app state.
///
/// Provides grouped sections for:
/// - Current AppEnvironment and configuration
/// - Dependency container summary
/// - Mock data sets loader (placeholder for SPRD-46)
///
/// Only available in DEBUG builds. Accessible as a navigation destination
/// via the Debug tab (iPhone) or sidebar item (iPad).
struct DebugMenuView: View {
    /// The dependency container for inspecting repository types.
    let container: DependencyContainer

    private var environment: AppEnvironment {
        AppEnvironment.current
    }

    var body: some View {
        List {
            environmentSection
            dependenciesSection
            mockDataSection
            buildInfoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Debug")
    }

    // MARK: - Environment Section

    private var environmentSection: some View {
        Section {
            LabeledContent("Current", value: environment.rawValue)
            LabeledContent("Container Name", value: environment.containerName)
            LabeledContent("In-Memory Only", value: environment.isStoredInMemoryOnly ? "Yes" : "No")
            LabeledContent("Uses Mock Data", value: environment.usesMockData ? "Yes" : "No")
        } header: {
            Label("Environment", systemImage: "gearshape.2")
        } footer: {
            Text("Current AppEnvironment resolved from launch arguments, environment variables, or build configuration.")
        }
    }

    // MARK: - Dependencies Section

    private var dependenciesSection: some View {
        Section {
            let info = container.debugSummary
            LabeledContent("Tasks", value: info.shortTypeName(for: info.taskRepositoryType))
            LabeledContent("Spreads", value: info.shortTypeName(for: info.spreadRepositoryType))
            LabeledContent("Events", value: info.shortTypeName(for: info.eventRepositoryType))
            LabeledContent("Notes", value: info.shortTypeName(for: info.noteRepositoryType))
            LabeledContent("Collections", value: info.shortTypeName(for: info.collectionRepositoryType))
        } header: {
            Label("Dependencies", systemImage: "shippingbox")
        } footer: {
            Text("Repository implementations currently in use by the DependencyContainer.")
        }
    }

    // MARK: - Mock Data Section

    private var mockDataSection: some View {
        Section {
            // TODO: SPRD-46 - Implement mock data sets loader with overwrite + reload behavior
            Text("Mock data sets will be available here")
                .foregroundStyle(.secondary)
                .italic()
        } header: {
            Label("Mock Data Sets", systemImage: "doc.on.doc")
        } footer: {
            Text("Load predefined data sets to test various scenarios. Loading a data set will overwrite existing data.")
        }
    }

    // MARK: - Build Info Section

    private var buildInfoSection: some View {
        Section {
            LabeledContent("Configuration", value: "DEBUG")
            LabeledContent("Date", value: Date.now.formatted(date: .abbreviated, time: .shortened))
            launchArgumentsView
        } header: {
            Label("Build Info", systemImage: "info.circle")
        }
    }

    @ViewBuilder
    private var launchArgumentsView: some View {
        let args = ProcessInfo.processInfo.arguments.dropFirst()
        if args.isEmpty {
            LabeledContent("Launch Arguments", value: "None")
        } else {
            DisclosureGroup("Launch Arguments (\(args.count))") {
                ForEach(Array(args), id: \.self) { arg in
                    Text(arg)
                        .font(.caption)
                        .monospaced()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DebugMenuView(container: try! .makeForPreview())
    }
}
#endif
