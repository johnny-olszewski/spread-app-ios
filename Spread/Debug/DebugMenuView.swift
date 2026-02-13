#if DEBUG
import SwiftUI
import struct Auth.User

/// Debug menu for inspecting environment, dependencies, and app state.
///
/// Provides grouped sections for:
/// - Environment switcher with safe switch flow
/// - Current DataEnvironment and Supabase configuration
/// - App dependencies summary
/// - Mock data sets loader with overwrite + reload behavior
///
/// Only available in DEBUG builds. Accessible as a navigation destination
/// via the Debug tab (iPhone) or sidebar item (iPad).
struct DebugMenuView: View {
    /// The app dependencies for inspecting repository types.
    let dependencies: AppDependencies

    /// The journal manager for loading mock data sets.
    ///
    /// Debug data loading routes through JournalManager to ensure UI state
    /// stays synchronized with repository data.
    let journalManager: JournalManager

    /// The auth manager for inspecting authentication state.
    let authManager: AuthManager

    /// The sync engine for inspecting sync state.
    let syncEngine: SyncEngine?

    /// Callback when environment switch completes and restart is needed.
    var onRestartRequired: (() -> Void)?

    @State private var isLoading = false
    @State private var loadingDataSet: MockDataSet?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    // Environment switch state
    @State private var switchCoordinator: DataEnvironmentSwitchCoordinator?
    @State private var pendingTargetEnvironment: DataEnvironment?
    @State private var showProdConfirmation = false
    @State private var prodConfirmationText = ""
    @State private var showUnsyncedWarning = false
    @State private var unsyncedOutboxCount = 0
    @State private var showRestartRequired = false

    private var blockAllNetworkBinding: Binding<Bool> {
        guard let debugMonitor = dependencies.networkMonitor as? DebugNetworkMonitor else {
            return .constant(false)
        }
        return Binding(
            get: { debugMonitor.blockAllNetwork },
            set: { debugMonitor.blockAllNetwork = $0 }
        )
    }

    private var forcedAuthErrorBinding: Binding<ForcedAuthError?> {
        guard let debugService = authManager.service as? DebugAuthService else {
            return .constant(nil)
        }
        return Binding(
            get: { debugService.forcedAuthError },
            set: { debugService.forcedAuthError = $0 }
        )
    }

    var body: some View {
        List {
            buildInfoSection
            environmentSwitcherSection
            supabaseSection
            authSection
            syncSection
            dependenciesSection
            mockDataSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Debug")
        .disabled(isLoading || switchCoordinator?.isInProgress == true)
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
        .alert("Switch to Production", isPresented: $showProdConfirmation) {
            TextField("Type PRODUCTION to confirm", text: $prodConfirmationText)
                .textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) {
                prodConfirmationText = ""
                pendingTargetEnvironment = nil
            }
            Button("Switch", role: .destructive) {
                if prodConfirmationText.uppercased() == "PRODUCTION" {
                    Task {
                        await beginSwitch(to: .production)
                    }
                }
                prodConfirmationText = ""
            }
            .disabled(prodConfirmationText.uppercased() != "PRODUCTION")
        } message: {
            Text("Switching to production will sign you out and wipe all local data. Type PRODUCTION to confirm.")
        }
        .alert("Unsynced Data", isPresented: $showUnsyncedWarning) {
            Button("Cancel", role: .cancel) {
                switchCoordinator?.cancelSwitch()
                pendingTargetEnvironment = nil
            }
            Button("Switch Anyway", role: .destructive) {
                Task {
                    if let target = pendingTargetEnvironment {
                        await switchCoordinator?.confirmSwitchDespiteUnsyncedData(to: target)
                        checkForRestartRequired()
                    }
                }
            }
        } message: {
            Text("You have \(unsyncedOutboxCount) unsynced change(s) that will be lost. Are you sure you want to switch environments?")
        }
        .alert("Restart Required", isPresented: $showRestartRequired) {
            Button("OK") {
                onRestartRequired?()
            }
        } message: {
            Text("Environment switched successfully. Please restart the app for changes to take effect.")
        }
        .onAppear {
            initializeSwitchCoordinator()
        }
    }

    // MARK: - Environment Switcher Section

    private var environmentSwitcherSection: some View {
        Section {
            ForEach(DataEnvironment.allCases, id: \.rawValue) { env in
                environmentButton(for: env)
            }
        } header: {
            Label("Switch Environment", systemImage: "arrow.triangle.swap")
        } footer: {
            Text("Switching environments will sign out and wipe local data. Production requires confirmation.")
        }
    }

    @ViewBuilder
    private func environmentButton(for env: DataEnvironment) -> some View {
        Button {
            handleEnvironmentSwitch(to: env)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(env.displayName)
                        .fontWeight(.medium)
                    Text(environmentDescription(for: env))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if DataEnvironment.current == env {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if switchCoordinator?.isInProgress == true && pendingTargetEnvironment == env {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(DataEnvironment.current == env || switchCoordinator?.isInProgress == true)
    }

    private func environmentDescription(for env: DataEnvironment) -> String {
        switch env {
        case .localhost:
            "No network, any credentials work, mock data available"
        case .development:
            "Dev Supabase project, real auth required"
        case .production:
            "Prod Supabase project, real auth required"
        }
    }

    private func handleEnvironmentSwitch(to env: DataEnvironment) {
        pendingTargetEnvironment = env
        if env == .production {
            showProdConfirmation = true
        } else {
            Task {
                await beginSwitch(to: env)
            }
        }
    }

    private func initializeSwitchCoordinator() {
        guard switchCoordinator == nil else { return }
        let wiper = SwiftDataStoreWiper(modelContainer: dependencies.modelContainer)
        switchCoordinator = DataEnvironmentSwitchCoordinator(
            authManager: authManager,
            syncEngine: syncEngine,
            storeWiper: wiper
        )
    }

    private func beginSwitch(to env: DataEnvironment) async {
        initializeSwitchCoordinator()
        await switchCoordinator?.beginSwitch(to: env)
        checkForRestartRequired()
    }

    private func checkForRestartRequired() {
        guard let coordinator = switchCoordinator else { return }

        switch coordinator.phase {
        case .pendingConfirmation(let outboxCount):
            unsyncedOutboxCount = outboxCount
            showUnsyncedWarning = true
        case .restartRequired:
            showRestartRequired = true
        default:
            break
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

    // MARK: - Auth Section

    private var authSection: some View {
        Section {
            LabeledContent("Status", value: authManager.state.isSignedIn ? "Signed in" : "Signed out")
            if let email = authManager.userEmail {
                LabeledContent("User", value: email)
            }
            if let userId = authManager.state.user?.id.uuidString {
                LabeledContent("User ID", value: userId)
                    .font(.caption)
                    .monospaced()
            }
            LabeledContent("Backup Entitled", value: authManager.hasBackupEntitlement ? "Yes" : "No")

            Picker("Forced Auth Error", selection: forcedAuthErrorBinding) {
                Text("None").tag(nil as ForcedAuthError?)
                ForEach(ForcedAuthError.allCases, id: \.self) { error in
                    Text(error.displayName).tag(error as ForcedAuthError?)
                }
            }
        } header: {
            Label("Auth", systemImage: "person.badge.key")
        } footer: {
            Text("Forced auth error will cause the next sign-in attempt to fail with the selected error.")
        }
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
                LabeledContent("Network", value: dependencies.networkMonitor.isConnected ? "Connected" : "Disconnected")
                Toggle("Block Network", isOn: blockAllNetworkBinding)
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
            let info = dependencies.debugSummary
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
            DebugRepositoryListView(repositoryType: type, dependencies: dependencies)
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
            "trash"
        case .baseline:
            "doc.text"
        case .multiday:
            "calendar"
        case .boundary:
            "arrow.left.arrow.right"
        case .highVolume:
            "chart.bar.fill"
        case .inboxNextYear:
            "tray.full"
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
            dependencies: try! .makeForPreview(),
            journalManager: .previewInstance,
            authManager: .makeForPreview(),
            syncEngine: nil
        )
    }
}
#endif
