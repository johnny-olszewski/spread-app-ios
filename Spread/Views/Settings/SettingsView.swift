import SwiftUI

/// Settings view for configuring calendar preferences.
struct SettingsView: View {

    // MARK: - Properties

    /// The journal manager for reading and updating mode/weekday.
    @Bindable var journalManager: JournalManager

    /// Repository for persisting settings changes.
    let settingsRepository: any SettingsRepository

    /// The sync engine for triggering sync after settings changes.
    let syncEngine: SyncEngine?

    /// Whether a save operation is in progress.
    @State private var isSaving = false

    /// Error message to display if save fails.
    @State private var saveError: String?

    // MARK: - Body

    var body: some View {
        Form {
            calendarSection
            aboutSection
        }
        .alert("Couldn't Save Settings", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        Section {
            Picker("First Day of Week", selection: firstWeekdayBinding) {
                ForEach(FirstWeekday.allCases, id: \.self) { weekday in
                    Text(weekday.displayName).tag(weekday)
                }
            }
        } header: {
            Text("Calendar")
        }
    }

    /// Binding that updates JournalManager and persists on change.
    private var firstWeekdayBinding: Binding<FirstWeekday> {
        Binding(
            get: { journalManager.firstWeekday },
            set: { newValue in
                guard journalManager.firstWeekday != newValue else { return }
                journalManager.firstWeekday = newValue
                Task { await saveSettings() }
            }
        )
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About")
        }
    }

    /// The app version string from the main bundle.
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    // MARK: - Persistence

    /// Saves current settings to the repository and triggers sync.
    private func saveSettings() async {
        isSaving = true
        defer { isSaving = false }

        let weekdayValue = journalManager.firstWeekday.weekdayValue(using: journalManager.calendar)

        let existingSettings = await settingsRepository.getSettings()
        let settings: DataModel.Settings
        if let existing = existingSettings {
            existing.firstWeekday = weekdayValue
            settings = existing
        } else {
            settings = DataModel.Settings(firstWeekday: weekdayValue)
        }

        do {
            try await settingsRepository.save(settings)
            saveError = nil
            await syncEngine?.syncNow()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    NavigationStack {
        SettingsView(
            journalManager: .previewInstance,
            settingsRepository: EmptySettingsRepository(),
            syncEngine: nil
        )
        .navigationTitle("Settings")
    }
}
