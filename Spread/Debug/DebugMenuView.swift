#if DEBUG
import SwiftUI

/// Debug menu for inspecting environment, container, and app state.
///
/// Provides grouped sections for:
/// - Current AppEnvironment and configuration
/// - Dependency container summary
/// - Mock data sets loader with overwrite + reload behavior
///
/// Only available in DEBUG builds. Accessible as a navigation destination
/// via the Debug tab (iPhone) or sidebar item (iPad).
struct DebugMenuView: View {
    /// The dependency container for inspecting repository types.
    let container: DependencyContainer

    /// The journal manager for loading mock data sets.
    ///
    /// Debug data loading routes through JournalManager to ensure UI state
    /// stays synchronized with repository data.
    let journalManager: JournalManager

    @State private var isLoading = false
    @State private var loadingDataSet: MockDataSet?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    private var environment: AppEnvironment {
        AppEnvironment.current
    }

    var body: some View {
        List {
            environmentSection
            supabaseSection
            dependenciesSection
            mockDataSection
            buildInfoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Debug")
        .disabled(isLoading)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
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

    // MARK: - Supabase Section

    private var supabaseSection: some View {
        Section {
            LabeledContent("Environment", value: SupabaseConfiguration.environment.rawValue)
            LabeledContent("URL Host", value: supabaseHostLabel)
            LabeledContent("Override", value: supabaseOverrideLabel)

            Button("Use Development") {
                SupabaseConfiguration.useDevEnvironment()
            }

            Button("Use Production") {
                SupabaseConfiguration.useProdEnvironment()
            }

            Button("Clear Overrides") {
                SupabaseConfiguration.clearRuntimeOverrides()
            }
        } header: {
            Label("Supabase", systemImage: "cloud")
        } footer: {
            Text("Debug/QA builds can switch Supabase environments here. Release builds require explicit URL/key overrides.")
        }
    }

    private var supabaseHostLabel: String {
        SupabaseConfiguration.url.host ?? SupabaseConfiguration.url.absoluteString
    }

    private var supabaseOverrideLabel: String {
        SupabaseConfiguration.runtimeOverrideDescription
            ?? SupabaseConfiguration.explicitOverrideSourceDescription
            ?? "None"
    }

    // MARK: - Dependencies Section

    private var dependenciesSection: some View {
        Section {
            let info = container.debugSummary
            repositoryLink(
                type: .tasks,
                implementationName: info.shortTypeName(for: info.taskRepositoryType)
            )
            repositoryLink(
                type: .spreads,
                implementationName: info.shortTypeName(for: info.spreadRepositoryType)
            )
            repositoryLink(
                type: .events,
                implementationName: info.shortTypeName(for: info.eventRepositoryType)
            )
            repositoryLink(
                type: .notes,
                implementationName: info.shortTypeName(for: info.noteRepositoryType)
            )
            repositoryLink(
                type: .collections,
                implementationName: info.shortTypeName(for: info.collectionRepositoryType)
            )
        } header: {
            Label("Dependencies", systemImage: "shippingbox")
        } footer: {
            Text("Tap a repository to browse its contents. Shows implementation type in use.")
        }
    }

    private func repositoryLink(type: DebugRepositoryType, implementationName: String) -> some View {
        NavigationLink {
            DebugRepositoryListView(repositoryType: type, container: container)
        } label: {
            LabeledContent(type.title, value: implementationName)
        }
    }

    // MARK: - Mock Data Section

    private var mockDataSection: some View {
        Section {
            ForEach(MockDataSet.allCases, id: \.rawValue) { dataSet in
                mockDataSetButton(for: dataSet)
            }
        } header: {
            Label("Mock Data Sets", systemImage: "doc.on.doc")
        } footer: {
            Text("Load predefined data sets to test various scenarios. Loading a data set will overwrite existing data.")
        }
    }

    @ViewBuilder
    private func mockDataSetButton(for dataSet: MockDataSet) -> some View {
        Button {
            Task {
                await loadDataSet(dataSet)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(dataSet.displayName)
                            .fontWeight(.medium)

                        if loadingDataSet == dataSet {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text(dataSet.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: iconName(for: dataSet))
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(isLoading)
    }

    private func iconName(for dataSet: MockDataSet) -> String {
        switch dataSet {
        case .empty:
            return "trash"
        case .baseline:
            return "doc.text"
        case .multiday:
            return "calendar"
        case .boundary:
            return "arrow.left.arrow.right"
        case .highVolume:
            return "chart.bar.fill"
        case .inboxNextYear:
            return "tray.full"
        }
    }

    private func loadDataSet(_ dataSet: MockDataSet) async {
        isLoading = true
        loadingDataSet = dataSet

        do {
            // Load data through JournalManager to ensure UI state stays synchronized
            try await journalManager.loadMockDataSet(dataSet)

            successMessage = "\(dataSet.displayName) data set loaded successfully."
            showSuccess = true
        } catch {
            errorMessage = "Failed to load data set: \(error.localizedDescription)"
            showError = true
        }

        isLoading = false
        loadingDataSet = nil
    }

    // MARK: - Build Info Section

    private var buildInfoSection: some View {
        Section {
            LabeledContent("Configuration", value: BuildInfo.configurationName)
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
        DebugMenuView(
            container: try! .makeForPreview(),
            journalManager: .previewInstance
        )
    }
}
#endif
