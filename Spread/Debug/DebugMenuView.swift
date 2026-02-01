#if DEBUG
import SwiftUI

/// Debug menu for inspecting environment, container, and app state.
///
/// Provides grouped sections for:
/// - Current DataEnvironment and Supabase configuration
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

    /// The sync engine for inspecting sync state.
    let syncEngine: SyncEngine?

    @State private var isLoading = false
    @State private var loadingDataSet: MockDataSet?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var selectedDataEnvironment: DataEnvironment = DataEnvironment.current

    var body: some View {
        List {
            buildInfoSection
            dataEnvironmentSection
            supabaseSection
            syncSection
            dependenciesSection
            mockDataSection
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

    // MARK: - Data Environment Section

    private var dataEnvironmentSection: some View {
        Section {
            Picker("Target", selection: $selectedDataEnvironment) {
                ForEach(DataEnvironment.allCases, id: \.self) { env in
                    Text(env.displayName).tag(env)
                }
            }
            .onChange(of: selectedDataEnvironment) { _, newValue in
                DataEnvironment.persistSelection(newValue)
            }

            LabeledContent("Auth Required", value: selectedDataEnvironment.requiresAuth ? "Yes" : "No")
            LabeledContent("Sync Enabled", value: selectedDataEnvironment.syncEnabled ? "Yes" : "No")
            LabeledContent("Local Only", value: selectedDataEnvironment.isLocalOnly ? "Yes" : "No")

            if DataEnvironment.persistedSelection != nil {
                Button("Clear Persisted Selection") {
                    DataEnvironment.clearPersistedSelection()
                    selectedDataEnvironment = BuildInfo.defaultDataEnvironment
                }
            }
        } header: {
            Label("Data Environment", systemImage: "externaldrive.connected.to.line.below")
        } footer: {
            Text("Selects the data target (localhost/dev/prod). Persisted across launches in Debug/QA builds. Restart the app for changes to take full effect.")
        }
    }

    // MARK: - Supabase Section

    private var supabaseSection: some View {
        Section {
            LabeledContent("Available", value: SupabaseConfiguration.isAvailable ? "Yes" : "No")
            LabeledContent("URL Host", value: supabaseHostLabel)
            if let overrideSource = SupabaseConfiguration.explicitOverrideSourceDescription {
                LabeledContent("Override", value: overrideSource)
            }
        } header: {
            Label("Supabase", systemImage: "cloud")
        } footer: {
            Text("Supabase configuration is driven by the Data Environment. Use -SupabaseURL and -SupabaseKey launch arguments for explicit overrides.")
        }
    }

    private var supabaseHostLabel: String {
        SupabaseConfiguration.url.host ?? SupabaseConfiguration.url.absoluteString
    }

    // MARK: - Sync Section

    @ViewBuilder
    private var syncSection: some View {
        if let syncEngine {
            Section {
                LabeledContent("Status", value: syncEngine.status.displayText)
                LabeledContent("Outbox Count", value: "\(syncEngine.outboxCount)")
                if let lastSync = syncEngine.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSync.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Network", value: container.networkMonitor.isConnected ? "Connected" : "Disconnected")
                Button("Sync Now") {
                    Task {
                        await syncEngine.syncNow()
                    }
                }
                if !syncEngine.syncLog.entries.isEmpty {
                    DisclosureGroup("Sync Log (\(syncEngine.syncLog.entries.count))") {
                        ForEach(syncEngine.syncLog.entries) { entry in
                            HStack {
                                Circle()
                                    .fill(entry.level == .error ? Color.red : entry.level == .warning ? Color.orange : Color.green)
                                    .frame(width: 8, height: 8)
                                Text(entry.message)
                                    .font(.caption)
                                    .monospaced()
                            }
                        }
                    }
                }
            } header: {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            } footer: {
                Text("Current sync engine state. Tap 'Sync Now' to trigger a manual sync attempt.")
            }
        }
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

    @ViewBuilder
    private var mockDataSection: some View {
        if DataEnvironment.current == .localhost {
            Section {
                ForEach(MockDataSet.allCases, id: \.rawValue) { dataSet in
                    mockDataSetButton(for: dataSet)
                }
            } header: {
                Label("Mock Data Sets", systemImage: "doc.on.doc")
            } footer: {
                Text("Load predefined data sets to test various scenarios. Loading a data set will overwrite existing data. Only available in localhost mode.")
            }
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
            journalManager: .previewInstance,
            syncEngine: nil
        )
    }
}
#endif
