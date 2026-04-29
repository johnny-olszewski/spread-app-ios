#if DEBUG
import SwiftUI
import struct Auth.User

/// Debug menu for inspecting environment, dependencies, and app state.
///
/// Provides grouped sections for:
/// - Current DataEnvironment and Supabase configuration
/// - App dependencies summary
/// - Mock data sets loader with overwrite + reload behavior
///
/// Only available in debug-enabled builds. Accessible as a navigation destination
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

    /// Shared app clock for temporal-context inspection and localhost controls.
    let appClock: AppClock

    @State private var isLoading = false
    @State private var loadingDataSet: MockDataSet?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

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

    @State private var appearanceSettings = DebugAppearanceSettings.shared

    var body: some View {
        List {
            buildInfoSection
            appearanceSection
            temporalContextSection
            supabaseSection
            authSection
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

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            // Paper Tone
            Picker("Paper Tone", selection: $appearanceSettings.paperTone) {
                ForEach(DebugAppearanceSettings.PaperTonePreset.allCases) { preset in
                    HStack {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                        Text(preset.displayName)
                    }
                    .tag(preset)
                }
            }

            // Dot Grid
            Toggle("Dot Grid", isOn: $appearanceSettings.isDotGridVisible)

            if appearanceSettings.isDotGridVisible {
                LabeledContent("Dot Size: \(appearanceSettings.dotSize, specifier: "%.1f")pt") {
                    Slider(value: $appearanceSettings.dotSize, in: 0.5...4.0, step: 0.5)
                        .frame(width: 150)
                }

                LabeledContent("Spacing: \(appearanceSettings.dotSpacing, specifier: "%.0f")pt") {
                    Slider(value: $appearanceSettings.dotSpacing, in: 8...40, step: 2)
                        .frame(width: 150)
                }

                LabeledContent("Opacity: \(appearanceSettings.dotOpacity, specifier: "%.0f")%%") {
                    Slider(value: $appearanceSettings.dotOpacity, in: 0.05...0.5, step: 0.01)
                        .frame(width: 150)
                }
            }

            // Heading Font
            Picker("Heading Font", selection: $appearanceSettings.headingFont) {
                ForEach(DebugAppearanceSettings.HeadingFont.allCases) { font in
                    Text(font.displayName)
                        .tag(font)
                }
            }

            // Accent Color
            Picker("Accent Color", selection: $appearanceSettings.accentColor) {
                ForEach(DebugAppearanceSettings.AccentColorPreset.allCases) { preset in
                    HStack {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 16, height: 16)
                        Text(preset.displayName)
                    }
                    .tag(preset)
                }
            }

            // Reset
            Button("Reset to Defaults", role: .destructive) {
                appearanceSettings.resetToDefaults()
            }
        } header: {
            Label("Appearance", systemImage: "paintbrush")
        } footer: {
            Text("Override visual appearance settings for tuning. Changes apply immediately to spread content surfaces.")
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
            Text("Supabase configuration is driven by the resolved Data Environment. Debug localhost bypasses Supabase entirely.")
        }
    }

    // MARK: - Temporal Context Section

    @ViewBuilder
    private var temporalContextSection: some View {
        Section {
            LabeledContent("Now", value: temporalNowLabel)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalNow)
            LabeledContent("Time Zone", value: appClock.timeZone.identifier)
            LabeledContent("Locale", value: appClock.locale.identifier)
            LabeledContent("Calendar", value: appClock.calendar.identifier.debugName)
            LabeledContent("Override", value: appClock.isUsingFixedContext ? "Fixed" : "System")

            if DataEnvironment.current == .localhost {
                Button("Advance +1 Hour") {
                    appClock.advanceDebugClock(
                        by: DateComponents(hour: 1),
                        reason: .significantTimeChange
                    )
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalAdvanceHour)

                Button("Advance +1 Day") {
                    appClock.advanceDebugClock(
                        by: DateComponents(day: 1),
                        reason: .calendarDayChanged
                    )
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalAdvanceDay)

                Button("Use UTC Time Zone") {
                    guard let timeZone = TimeZone(identifier: "UTC") else { return }
                    appClock.setDebugTimeZone(timeZone)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetUTC)

                Button("Use New York Time Zone") {
                    guard let timeZone = TimeZone(identifier: "America/New_York") else { return }
                    appClock.setDebugTimeZone(timeZone)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetNewYork)

                Button("Use French Locale") {
                    appClock.setDebugLocale(Locale(identifier: "fr_FR"))
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetFrenchLocale)

                Button("Use POSIX English Locale") {
                    appClock.setDebugLocale(Locale(identifier: "en_US_POSIX"))
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetEnglishLocale)

                Button("Use Gregorian Calendar") {
                    appClock.setDebugCalendarIdentifier(.gregorian)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetGregorianCalendar)

                Button("Use Buddhist Calendar") {
                    appClock.setDebugCalendarIdentifier(.buddhist)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetBuddhistCalendar)

                Button("Resume Live System Clock", role: .destructive) {
                    appClock.clearDebugOverride(reason: .sceneDidBecomeActive)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalResumeLive)
            }
        } header: {
            Label("Temporal Context", systemImage: "clock")
        } footer: {
            Text("Localhost can freeze or mutate AppClock at runtime without rebuilding the app runtime. Production builds expose no temporal controls.")
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

    private var debugSyncPolicy: DebugSyncPolicy? {
        syncEngine?.policy as? DebugSyncPolicy
    }

    private var disableSyncBinding: Binding<Bool> {
        guard let policy = debugSyncPolicy else {
            return .constant(false)
        }
        return Binding(
            get: { policy.isSyncDisabled },
            set: { policy.isSyncDisabled = $0 }
        )
    }

    private var forceSyncFailureBinding: Binding<Bool> {
        guard let policy = debugSyncPolicy else {
            return .constant(false)
        }
        return Binding(
            get: { policy.isForceSyncFailure },
            set: { policy.isForceSyncFailure = $0 }
        )
    }

    @ViewBuilder
    private var syncSection: some View {
        if let syncEngine {
            Section {
                // Live readout
                LabeledContent("Status", value: syncEngine.status.displayText)
                LabeledContent("Outbox Count", value: "\(syncEngine.outboxCount)")
                if let lastSync = syncEngine.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSync.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Network", value: dependencies.networkMonitor.isConnected ? "Connected" : "Disconnected")

                // Controls
                Toggle("Block Network", isOn: blockAllNetworkBinding)
                Toggle("Disable Sync", isOn: disableSyncBinding)
                Toggle("Force Sync Failure", isOn: forceSyncFailureBinding)

                Button("Force Syncing (5s)") {
                    Task {
                        debugSyncPolicy?.forcedSyncingDuration = 5
                        await syncEngine.syncNow()
                        debugSyncPolicy?.forcedSyncingDuration = nil
                    }
                }

                Button("Force Status: Idle") {
                    syncEngine.status = .idle
                }
                Button("Force Status: Synced") {
                    syncEngine.status = .synced(.now)
                }
                Button("Force Status: Error") {
                    syncEngine.status = .error("Debug: forced sync failure")
                }
                Button("Force Status: Offline") {
                    syncEngine.status = .offline
                }

                Button("Seed Outbox (5 mutations)") {
                    seedOutbox(count: 5, syncEngine: syncEngine)
                }

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
                Text("Current sync engine state. Disable Sync blocks auto/manual triggers. Force Syncing pins the UI for 5s.")
            }

            // Scenario presets
            Section {
                Button("Offline + Auth Error") {
                    applyPreset(.offlineAuthError)
                }
                Button("Sync Backlog") {
                    applyPreset(.syncBacklog(syncEngine: syncEngine))
                }
                Button("All Failures") {
                    applyPreset(.allFailures)
                }
                Button("Reset All Overrides", role: .destructive) {
                    resetAllOverrides(syncEngine: syncEngine)
                }
            } header: {
                Label("Scenario Presets", systemImage: "theatermask.and.paintbrush")
            } footer: {
                Text("Apply multiple debug overrides at once. Reset clears all network, auth, and sync overrides.")
            }
        }
    }

    // MARK: - Outbox Seeding

    private func seedOutbox(count: Int, syncEngine: SyncEngine) {
        for _ in 0..<count {
            let entityId = UUID()
            let fakeData = try! JSONSerialization.data(
                withJSONObject: ["id": entityId.uuidString, "title": "Debug seed"],
                options: []
            )
            syncEngine.enqueueMutation(
                entityType: .task,
                entityId: entityId,
                operation: .create,
                recordData: fakeData,
                changedFields: ["title"]
            )
        }
        syncEngine.refreshOutboxCount()
    }

    // MARK: - Scenario Presets

    private enum ScenarioPreset {
        case offlineAuthError
        case syncBacklog(syncEngine: SyncEngine)
        case allFailures
    }

    private func applyPreset(_ preset: ScenarioPreset) {
        switch preset {
        case .offlineAuthError:
            (dependencies.networkMonitor as? DebugNetworkMonitor)?.blockAllNetwork = true
            (authManager.service as? DebugAuthService)?.forcedAuthError = .invalidCredentials

        case .syncBacklog(let engine):
            seedOutbox(count: 10, syncEngine: engine)

        case .allFailures:
            (dependencies.networkMonitor as? DebugNetworkMonitor)?.blockAllNetwork = true
            (authManager.service as? DebugAuthService)?.forcedAuthError = .invalidCredentials
            debugSyncPolicy?.isForceSyncFailure = true
        }
    }

    private func resetAllOverrides(syncEngine: SyncEngine) {
        (dependencies.networkMonitor as? DebugNetworkMonitor)?.blockAllNetwork = false
        (authManager.service as? DebugAuthService)?.forcedAuthError = nil
        debugSyncPolicy?.resetAll()
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
                ForEach(MockDataSet.debugMenuCases, id: \.rawValue) { dataSet in
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
        case .scenarioAssignmentExistingSpread,
                .scenarioAssignmentInboxFallback,
                .scenarioInboxResolution,
                .scenarioMigrationMonthBound,
                .scenarioMigrationDayUpgrade,
                .scenarioMigrationDaySuperseded,
                .scenarioReassignment,
                .scenarioOverdueReview,
                .scenarioOverdueInbox,
                .scenarioTraditionalOverdue,
                .scenarioNoteExclusions,
                .scenarioMultidayLayout,
                .scenarioSpreadNavigator:
            "testtube.2"
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

    private var temporalNowLabel: String {
        appClock.now.formatted(date: .abbreviated, time: .shortened)
    }
}

private extension Calendar.Identifier {
    var debugName: String {
        switch self {
        case .gregorian:
            return "gregorian"
        case .bangla:
            return "bangla"
        case .buddhist:
            return "buddhist"
        case .chinese:
            return "chinese"
        case .coptic:
            return "coptic"
        case .ethiopicAmeteAlem:
            return "ethiopicAmeteAlem"
        case .ethiopicAmeteMihret:
            return "ethiopicAmeteMihret"
        case .gujarati:
            return "gujarati"
        case .hebrew:
            return "hebrew"
        case .indian:
            return "indian"
        case .islamic:
            return "islamic"
        case .islamicCivil:
            return "islamicCivil"
        case .islamicTabular:
            return "islamicTabular"
        case .islamicUmmAlQura:
            return "islamicUmmAlQura"
        case .iso8601:
            return "iso8601"
        case .japanese:
            return "japanese"
        case .persian:
            return "persian"
        case .republicOfChina:
            return "republicOfChina"
        @unknown default:
            return "unknown"
        }
    }
}

#Preview {
    NavigationStack {
        DebugMenuView(
            dependencies: try! .makeForPreview(),
            journalManager: .previewInstance,
            authManager: .makeForPreview(),
            syncEngine: nil,
            appClock: .live()
        )
    }
}
#endif
