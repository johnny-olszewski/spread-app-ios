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

    var body: some View {
        List {
            buildInfoSection
            featureFlagsSection
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

    // MARK: - Feature Flags Section

    /// Live feature-flag overrides. Toggling persists to `UserDefaults` and updates
    /// gated UI (e.g. the Collections tab) immediately, since `FeatureFlagService`
    /// is `@Observable` (SPRD-310). Only shown when the injected provider is the
    /// concrete overridable service.
    @ViewBuilder
    private var featureFlagsSection: some View {
        if let service = dependencies.featureFlags as? FeatureFlagService {
            Section {
                ForEach(FeatureFlag.allCases, id: \.self) { flag in
                    Toggle(flag.displayName, isOn: Binding(
                        get: { service.isEnabled(flag) },
                        set: { service.setOverride($0, for: flag) }
                    ))
                }
                if FeatureFlag.allCases.contains(where: { service.override(for: $0) != nil }) {
                    Button("Clear Overrides") {
                        for flag in FeatureFlag.allCases {
                            service.setOverride(nil, for: flag)
                        }
                    }
                }
            } header: {
                Text("Feature Flags")
            } footer: {
                Text("Overrides persist on this device and take effect immediately.")
            }
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
            Label { Text("Supabase") } icon: { SpreadTheme.Icon.cloud.sized(SpreadTheme.IconSize.medium) }
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
            Label { Text("Temporal Context") } icon: { SpreadTheme.Icon.clock.sized(SpreadTheme.IconSize.medium) }
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
                    .font(SpreadTheme.Typography.caption)
                    .monospaced()
            }
        } header: {
            Label { Text("Auth") } icon: { SpreadTheme.Icon.key.sized(SpreadTheme.IconSize.medium) }
        }
    }

    // MARK: - Sync Section

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
                                    .font(SpreadTheme.Typography.caption)
                                    .monospaced()
                            }
                        }
                    }
                }
            } header: {
                Label { Text("Sync") } icon: { SpreadTheme.Icon.arrowsClockwise.sized(SpreadTheme.IconSize.medium) }
            } footer: {
                Text("Current sync engine state.")
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
            Label { Text("Dependencies") } icon: { SpreadTheme.Icon.package.sized(SpreadTheme.IconSize.medium) }
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
                Label { Text("Mock Data Sets") } icon: { SpreadTheme.Icon.copy.sized(SpreadTheme.IconSize.medium) }
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
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                icon(for: dataSet).sized(SpreadTheme.IconSize.medium)
                    .iconTint(.secondary)
            }
        }
        .disabled(isLoading)
    }

    private func icon(for dataSet: MockDataSet) -> SpreadTheme.Icon {
        switch dataSet {
        case .empty:
            .trash
        case .baseline:
            .document
        case .multiday:
            .calendar
        case .boundary:
            .arrowsLeftRight
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
            .testTube
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
            Label { Text("Build Info") } icon: { SpreadTheme.Icon.info.sized(SpreadTheme.IconSize.medium) }
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
                        .font(SpreadTheme.Typography.caption)
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
