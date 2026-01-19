import SwiftUI

/// Modal sheet for creating a new spread.
///
/// Supports creation of year, month, day, and multiday spreads with:
/// - Period selection via segmented picker
/// - Date picker for year/month/day periods
/// - Preset buttons and custom date range for multiday
/// - Validation messages and duplicate detection
struct SpreadCreationSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// The journal manager for spread creation.
    @Bindable var journalManager: JournalManager

    /// The user's first day of week preference.
    let firstWeekday: FirstWeekday

    /// Callback when a spread is created.
    let onSpreadCreated: (DataModel.Spread) -> Void

    // MARK: - State

    @State private var selectedPeriod: Period = .day
    @State private var selectedDate: Date = Date()
    @State private var multidayStartDate: Date = Date()
    @State private var multidayEndDate: Date = Date()
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Computed Properties

    private var configuration: SpreadCreationConfiguration {
        SpreadCreationConfiguration(
            calendar: journalManager.calendar,
            today: journalManager.today,
            firstWeekday: firstWeekday,
            existingSpreads: journalManager.spreads
        )
    }

    private var creatablePeriods: [Period] {
        [.year, .month, .day, .multiday]
    }

    private var validationResult: SpreadCreationResult {
        if selectedPeriod == .multiday {
            return configuration.canCreateMultiday(
                startDate: multidayStartDate,
                endDate: multidayEndDate
            )
        } else {
            return configuration.canCreate(period: selectedPeriod, date: selectedDate)
        }
    }

    private var canCreate: Bool {
        validationResult.isValid
    }

    private var validationMessage: String? {
        validationResult.error?.message
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                periodSection
                dateSection
                validationSection
            }
            .navigationTitle("New Spread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSpread()
                    }
                    .disabled(!canCreate || isCreating)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPeriod) { _, newPeriod in
                adjustDatesForPeriod(newPeriod)
            }
            .onAppear {
                initializeDates()
            }
        }
    }

    // MARK: - Sections

    private var periodSection: some View {
        Section {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(creatablePeriods, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.periodSegment(
                                period.rawValue
                            )
                        )
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.periodPicker)

            Text(SpreadCreationConfiguration.periodDescription(for: selectedPeriod))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Spread Type")
        }
    }

    @ViewBuilder
    private var dateSection: some View {
        if selectedPeriod == .multiday {
            multidayDateSection
        } else {
            standardDateSection
        }
    }

    private var standardDateSection: some View {
        Section {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: configuration.minimumDate(for: selectedPeriod)...configuration.maximumDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
        } header: {
            Text("Date")
        }
    }

    private var multidayDateSection: some View {
        Section {
            // Preset buttons
            presetsRow

            Divider()

            // Custom date range
            DatePicker(
                "Start Date",
                selection: $multidayStartDate,
                in: configuration.minimumMultidayStartDate...configuration.maximumDate,
                displayedComponents: [.date]
            )

            DatePicker(
                "End Date",
                selection: $multidayEndDate,
                in: configuration.minimumMultidayEndDate...configuration.maximumDate,
                displayedComponents: [.date]
            )
        } header: {
            Text("Date Range")
        }
    }

    private var presetsRow: some View {
        HStack(spacing: 12) {
            ForEach(MultidayPreset.allCases, id: \.self) { preset in
                presetButton(for: preset)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func presetButton(for preset: MultidayPreset) -> some View {
        Button {
            applyPreset(preset)
        } label: {
            Text(preset.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                )
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var validationSection: some View {
        if let message = validationMessage {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func initializeDates() {
        let today = journalManager.today
        selectedDate = today
        multidayStartDate = today
        multidayEndDate = journalManager.calendar.date(byAdding: .day, value: 6, to: today) ?? today
    }

    private func adjustDatesForPeriod(_ period: Period) {
        let minDate = configuration.minimumDate(for: period)

        // Ensure selected date is within valid range
        if selectedDate < minDate {
            selectedDate = minDate
        }
    }

    private func applyPreset(_ preset: MultidayPreset) {
        guard let range = configuration.dateRange(for: preset) else { return }
        multidayStartDate = range.startDate
        multidayEndDate = range.endDate
    }

    private func createSpread() {
        guard canCreate else {
            if let message = validationMessage {
                errorMessage = message
                showingError = true
            }
            return
        }

        isCreating = true

        Task {
            do {
                if selectedPeriod == .multiday {
                    let spread = try await journalManager.addMultidaySpread(
                        startDate: multidayStartDate,
                        endDate: multidayEndDate
                    )
                    await MainActor.run {
                        onSpreadCreated(spread)
                        dismiss()
                    }
                } else {
                    let spread = try await journalManager.addSpread(
                        period: selectedPeriod,
                        date: selectedDate
                    )
                    await MainActor.run {
                        onSpreadCreated(spread)
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create spread: \(error.localizedDescription)"
                    showingError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Create Spread") {
    SpreadCreationSheet(
        journalManager: .previewInstance,
        firstWeekday: .sunday,
        onSpreadCreated: { spread in
            print("Created spread: \(spread.period)")
        }
    )
}
