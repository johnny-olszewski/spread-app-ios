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

    /// Optional callback to trigger data reload after loading a mock data set.
    var onDataReload: (() async -> Void)?

    @State private var isLoading = false
    @State private var loadingDataSet: MockDataSet?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    private var environment: AppEnvironment {
        AppEnvironment.current
    }

    private var dataService: DebugDataService {
        DebugDataService(
            taskRepository: container.taskRepository,
            spreadRepository: container.spreadRepository,
            eventRepository: container.eventRepository,
            noteRepository: container.noteRepository
        )
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
        }
    }

    private func loadDataSet(_ dataSet: MockDataSet) async {
        isLoading = true
        loadingDataSet = dataSet

        do {
            try await dataService.loadDataSet(
                dataSet,
                calendar: .current,
                today: .now
            )

            // Trigger data reload if callback is provided
            await onDataReload?()

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
