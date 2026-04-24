import SwiftUI

/// Settings view for configuring BuJo mode and calendar preferences.
///
/// Provides sections for:
/// 1. Task Management Style — radio-button selection between conventional and traditional modes
/// 2. Calendar Preferences — first day of week picker
/// 3. About — app version and credits
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

    /// Local-only title-strip display preference. This intentionally does not sync.
    @AppStorage(TitleStripDisplayPreference.storageKey)
    private var titleStripDisplayPreferenceRaw = TitleStripDisplayPreference.defaultValue.rawValue

    // MARK: - Body

    var body: some View {
        Form {
            modeSection
            calendarSection
            titleStripSection
            aboutSection
        }
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        Section {
            ForEach(BujoMode.allCases, id: \.self) { mode in
                ModeSelectionRow(
                    mode: mode,
                    isSelected: journalManager.bujoMode == mode
                ) {
                    guard journalManager.bujoMode != mode else { return }
                    journalManager.bujoMode = mode
                    Task { await saveSettings() }
                }
            }
        } header: {
            Text("Task Management Style")
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

    // MARK: - Title Strip Section

    private var titleStripSection: some View {
        Section {
            Picker("Display", selection: titleStripDisplayPreferenceBinding) {
                ForEach(TitleStripDisplayPreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Settings.titleStripDisplayPicker)
        } header: {
            Text("Title Strip")
        } footer: {
            Text("Filtered mode keeps current and future spreads plus favorited or open-task past spreads visible. Use the chevron navigator for complete spread navigation.")
        }
    }

    /// Binding that persists only to UserDefaults via AppStorage.
    private var titleStripDisplayPreferenceBinding: Binding<TitleStripDisplayPreference> {
        Binding(
            get: { TitleStripDisplayPreference(storedRawValue: titleStripDisplayPreferenceRaw) },
            set: { titleStripDisplayPreferenceRaw = $0.rawValue }
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

        // Load existing settings to preserve the ID, or create new
        let existingSettings = await settingsRepository.getSettings()
        let settings: DataModel.Settings
        if let existing = existingSettings {
            existing.bujoMode = journalManager.bujoMode
            existing.firstWeekday = weekdayValue
            settings = existing
        } else {
            settings = DataModel.Settings(
                bujoMode: journalManager.bujoMode,
                firstWeekday: weekdayValue
            )
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

// MARK: - Mode Selection Row

/// A row that displays a BuJo mode option with radio-button style selection.
private struct ModeSelectionRow: View {
    let mode: BujoMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accent : .secondary)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.Settings.modeOption(mode.rawValue)
        )
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
