import SwiftUI

/// Modal sheet for creating a new spread or editing a multiday spread date range.
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

    /// Optional prefill for year/month/day recommendations.
    let initialPeriod: Period?
    let initialDate: Date?

    /// The shared sheet mode.
    let mode: SpreadCreationSheetMode

    /// The multiday spread being edited when the sheet is in date-editing mode.
    let editingSpread: DataModel.Spread?

    /// Callback when a spread is created.
    let onSpreadCreated: (DataModel.Spread) -> Void

    /// Callback when an existing multiday spread date range is saved.
    let onSpreadDatesSaved: (DataModel.Spread) -> Void
    private let presentedTemporalContext: PresentedTemporalContext

    // MARK: - State

    @State private var selectedPeriod: Period = .day
    @State private var selectedDate: Date = Date()
    @State private var multidayStartDate: Date = Date()
    @State private var multidayEndDate: Date = Date()
    @State private var customName: String = ""
    @State private var usesDynamicName: Bool = true
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Initialization

    init(
        journalManager: JournalManager,
        firstWeekday: FirstWeekday,
        initialPeriod: Period? = nil,
        initialDate: Date? = nil,
        onSpreadCreated: @escaping (DataModel.Spread) -> Void
    ) {
        self.journalManager = journalManager
        self.firstWeekday = firstWeekday
        self.initialPeriod = initialPeriod
        self.initialDate = initialDate
        self.presentedTemporalContext = PresentedTemporalContext(journalManager: journalManager)
        self.mode = .create
        self.editingSpread = nil
        self.onSpreadCreated = onSpreadCreated
        self.onSpreadDatesSaved = { _ in }

        let period = initialPeriod ?? .day
        let date = initialDate ?? presentedTemporalContext.today
        self._selectedPeriod = State(initialValue: period)
        self._selectedDate = State(initialValue: period.normalizeDate(date, calendar: presentedTemporalContext.calendar))
        self._multidayStartDate = State(initialValue: presentedTemporalContext.today)
        self._multidayEndDate = State(
            initialValue: presentedTemporalContext.calendar.date(
                byAdding: .day,
                value: 6,
                to: presentedTemporalContext.today
            ) ?? presentedTemporalContext.today
        )
        self._customName = State(initialValue: "")
        self._usesDynamicName = State(initialValue: true)
    }

    init(
        journalManager: JournalManager,
        firstWeekday: FirstWeekday,
        editingMultidaySpread spread: DataModel.Spread,
        onSpreadDatesSaved: @escaping (DataModel.Spread) -> Void
    ) {
        self.journalManager = journalManager
        self.firstWeekday = firstWeekday
        self.initialPeriod = .multiday
        self.initialDate = spread.startDate ?? spread.date
        self.presentedTemporalContext = PresentedTemporalContext(journalManager: journalManager)
        self.mode = .editDates(
            spreadID: spread.id,
            originalStartDate: spread.startDate ?? spread.date,
            originalEndDate: spread.endDate ?? spread.date
        )
        self.editingSpread = spread
        self.onSpreadCreated = { _ in }
        self.onSpreadDatesSaved = onSpreadDatesSaved

        let startDate = (spread.startDate ?? spread.date).startOfDay(calendar: presentedTemporalContext.calendar)
        let endDate = (spread.endDate ?? spread.date).startOfDay(calendar: presentedTemporalContext.calendar)
        self._selectedPeriod = State(initialValue: .multiday)
        self._selectedDate = State(initialValue: startDate)
        self._multidayStartDate = State(initialValue: startDate)
        self._multidayEndDate = State(initialValue: endDate)
        self._customName = State(initialValue: "")
        self._usesDynamicName = State(initialValue: true)
    }

    // MARK: - Computed Properties

    private var configuration: SpreadCreationConfiguration {
        SpreadCreationConfiguration(
            calendar: presentedTemporalContext.calendar,
            today: presentedTemporalContext.today,
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
                endDate: multidayEndDate,
                ignoringSpreadID: mode.editingSpreadID
            )
        } else {
            return configuration.canCreate(period: selectedPeriod, date: selectedDate)
        }
    }

    private var isUnchangedRange: Bool {
        guard case .editDates(_, let originalStartDate, let originalEndDate) = mode else {
            return false
        }
        return configuration.isUnchangedMultidayRange(
            startDate: multidayStartDate,
            endDate: multidayEndDate,
            originalStartDate: originalStartDate,
            originalEndDate: originalEndDate
        )
    }

    private var canSubmit: Bool {
        validationResult.isValid && !isUnchangedRange
    }

    private var validationMessage: String? {
        validationResult.error?.message
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    periodSection
                    if mode.showsPeriodPicker {
                        compactDivider
                    }
                    dateSection
                    if mode.showsNameControls {
                        compactDivider
                        nameSection
                    }
                    if let message = validationMessage {
                        compactDivider
                        validationSection(message: message)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.confirmationTitle) {
                        submit()
                    }
                    .disabled(!canSubmit || isCreating)
                    .accessibilityIdentifier(submitButtonAccessibilityIdentifier)
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
        }
        .localhostTemporalHarness(
            presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics(
                calendarIdentifier: presentedTemporalContext.calendar.identifier,
                today: presentedTemporalContext.today
            )
        )
    }

    // MARK: - Sections

    private var periodSection: some View {
        Group {
            if mode.showsPeriodPicker {
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("Spread Type")
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
                }
            }
        }
    }

    private var submitButtonAccessibilityIdentifier: String {
        switch mode {
        case .create:
            return Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton
        case .editDates:
            return Definitions.AccessibilityIdentifiers.SpreadCreationSheet.saveButton
        }
    }

    private var multidayStartDateRange: ClosedRange<Date> {
        let lowerBound: Date
        if case .editDates(_, let originalStartDate, _) = mode {
            lowerBound = min(
                originalStartDate.startOfDay(calendar: presentedTemporalContext.calendar),
                configuration.minimumMultidayStartDate
            )
        } else {
            lowerBound = configuration.minimumMultidayStartDate
        }
        return lowerBound...configuration.maximumDate
    }

    private var multidayEndDateRange: ClosedRange<Date> {
        let lowerBound: Date
        if case .editDates(_, _, let originalEndDate) = mode {
            lowerBound = min(
                originalEndDate.startOfDay(calendar: presentedTemporalContext.calendar),
                configuration.minimumMultidayEndDate
            )
        } else {
            lowerBound = configuration.minimumMultidayEndDate
        }
        return lowerBound...configuration.maximumDate
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
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Date")
            PeriodDatePicker(
                period: selectedPeriod,
                selectedDate: $selectedDate,
                calendar: presentedTemporalContext.calendar,
                today: presentedTemporalContext.today,
                minimumDate: configuration.minimumDate(for: .day),
                maximumDate: configuration.maximumDate,
                accessibilityIdentifiers: .init(
                    dayPicker: Definitions.AccessibilityIdentifiers.SpreadCreationSheet.standardDatePicker,
                    yearPicker: Definitions.AccessibilityIdentifiers.SpreadCreationSheet.yearPicker,
                    monthPicker: Definitions.AccessibilityIdentifiers.SpreadCreationSheet.monthPicker,
                    monthYearPicker: Definitions.AccessibilityIdentifiers.SpreadCreationSheet.monthYearPicker
                )
            )
        }
    }

    private var multidayDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Date Range")
            // Preset buttons
            presetsRow
            compactDivider
            // Custom date range
            DatePicker(
                "Start Date",
                selection: $multidayStartDate,
                in: multidayStartDateRange,
                displayedComponents: [.date]
            )
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayStartDatePicker)

            DatePicker(
                "End Date",
                selection: $multidayEndDate,
                in: multidayEndDateRange,
                displayedComponents: [.date]
            )
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayEndDatePicker)
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
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayPreset(
                multidayPresetIdentifier(for: preset)
            )
        )
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Name")
            TextField("Custom name", text: $customName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.customNameField)

            Toggle("Use dynamic name when custom name is empty", isOn: $usesDynamicName)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadCreationSheet.dynamicNameToggle)
        }
    }

    private func validationSection(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var compactDivider: some View {
        Divider()
            .padding(.vertical, 2)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func adjustDatesForPeriod(_ period: Period) {
        guard period != .multiday else { return }
        let minDate = configuration.minimumDate(for: period)

        // Normalize selection to the period and clamp to minimum date.
        let normalizedSelected = period.normalizeDate(selectedDate, calendar: presentedTemporalContext.calendar)
        selectedDate = normalizedSelected < minDate ? minDate : normalizedSelected
    }

    private func applyPreset(_ preset: MultidayPreset) {
        guard let range = configuration.dateRange(for: preset) else { return }
        multidayStartDate = range.startDate
        multidayEndDate = range.endDate
    }

    private func multidayPresetIdentifier(for preset: MultidayPreset) -> String {
        switch preset {
        case .thisWeek:
            return "thisWeek"
        case .nextWeek:
            return "nextWeek"
        }
    }

    private func submit() {
        guard canSubmit else {
            if let message = validationMessage {
                errorMessage = message
                showingError = true
            }
            return
        }

        isCreating = true

        Task {
            do {
                switch mode {
                case .create:
                    try await createSpread()
                case .editDates:
                    try await saveEditedDates()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to \(mode == .create ? "create" : "save") spread: \(error.localizedDescription)"
                    showingError = true
                    isCreating = false
                }
            }
        }
    }

    private func createSpread() async throws {
        if selectedPeriod == .multiday {
            let spread = try await journalManager.addMultidaySpread(
                startDate: multidayStartDate,
                endDate: multidayEndDate,
                customName: customName,
                usesDynamicName: usesDynamicName
            )
            await MainActor.run {
                onSpreadCreated(spread)
                dismiss()
            }
        } else {
            let spread = try await journalManager.addSpread(
                period: selectedPeriod,
                date: selectedDate,
                customName: customName,
                usesDynamicName: usesDynamicName
            )
            await MainActor.run {
                onSpreadCreated(spread)
                dismiss()
            }
        }
    }

    private func saveEditedDates() async throws {
        guard let editingSpread else { return }
        let spread = try await journalManager.updateMultidaySpreadDates(
            editingSpread,
            startDate: multidayStartDate,
            endDate: multidayEndDate
        )
        await MainActor.run {
            onSpreadDatesSaved(spread)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Create Spread") {
    
    VStack {
        
    }
    .sheet(isPresented: .constant(true)) {
        SpreadCreationSheet(
            journalManager: .previewInstance,
            firstWeekday: .sunday,
            onSpreadCreated: { spread in
                print("Created spread: \(spread.period)")
            }
        )
    }
}
