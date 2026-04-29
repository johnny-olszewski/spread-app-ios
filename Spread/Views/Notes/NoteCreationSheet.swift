import SwiftUI

/// Modal sheet for creating a new note.
///
/// Supports note creation with:
/// - Title input (required, auto-focused)
/// - Content input (optional multiline text)
/// - Period selection (year/month/day only)
/// - Period-appropriate date picker
/// - Inline validation with Create button visibility rules
struct NoteCreationSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// The journal manager for note creation.
    @Bindable var journalManager: JournalManager

    /// The currently selected spread, used for defaults.
    let selectedSpread: DataModel.Spread?

    /// Callback when a note is created.
    let onNoteCreated: (DataModel.Note) -> Void

    // MARK: - State

    @State private var presentedTemporalContext: PresentedTemporalContext
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedPeriod: Period = .day
    @State private var selectedDate: Date = Date()
    @State private var hasEditedTitle = false
    @State private var showValidationErrors = false
    @State private var isCreating = false
    @State private var titleError: NoteCreationError?
    @State private var dateError: NoteCreationError?
    @State private var isShowingSpreadPicker = false
    @FocusState private var isTitleFocused: Bool

    init(
        journalManager: JournalManager,
        selectedSpread: DataModel.Spread?,
        onNoteCreated: @escaping (DataModel.Note) -> Void
    ) {
        self.journalManager = journalManager
        self.selectedSpread = selectedSpread
        self.onNoteCreated = onNoteCreated
        let presentedTemporalContext = PresentedTemporalContext(journalManager: journalManager)
        _presentedTemporalContext = State(initialValue: presentedTemporalContext)

        let configuration = NoteCreationConfiguration(
            calendar: presentedTemporalContext.calendar,
            today: presentedTemporalContext.today
        )
        let defaults = configuration.defaultSelection(from: selectedSpread)
        let minimumDate = configuration.minimumDate(for: defaults.period)
        let normalizedDate = defaults.period.normalizeDate(defaults.date, calendar: presentedTemporalContext.calendar)
        _selectedPeriod = State(initialValue: defaults.period)
        _selectedDate = State(initialValue: normalizedDate < minimumDate ? minimumDate : normalizedDate)
    }

    // MARK: - Computed Properties

    private var configuration: NoteCreationConfiguration {
        NoteCreationConfiguration(
            calendar: presentedTemporalContext.calendar,
            today: presentedTemporalContext.today
        )
    }

    /// Whether the Create button should be visible.
    ///
    /// Hidden until title is edited once; then always visible.
    private var isCreateButtonVisible: Bool {
        hasEditedTitle
    }

    /// Whether the form has any validation errors.
    private var hasValidationErrors: Bool {
        let result = configuration.validate(
            title: title,
            period: selectedPeriod,
            date: selectedDate
        )
        return !result.isValid
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    titleSection
                    compactDivider
                    contentSection
                    compactDivider
                    spreadSelectionSection
                    compactDivider
                    periodSection
                    compactDivider
                    dateSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .sheet(isPresented: $isShowingSpreadPicker) {
                SpreadPickerView(
                    spreads: journalManager.spreads,
                    calendar: presentedTemporalContext.calendar,
                    today: presentedTemporalContext.today,
                    onSpreadSelected: { period, date in
                        selectedPeriod = period
                        selectedDate = date
                        clearDateError()
                    },
                    onChooseCustomDate: {
                        // Stay on custom date entry - no action needed
                    }
                )
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreateButtonVisible {
                        Button("Create") {
                            attemptCreate()
                        }
                        .disabled(isCreating)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.createButton)
                    }
                }
            }
            .onAppear { isTitleFocused = true }
            .onChange(of: selectedPeriod) { _, newPeriod in
                adjustDateForPeriod(newPeriod)
                clearDateError()
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Title")
            TextField("Note title", text: $title)
                .focused($isTitleFocused)
                .onChange(of: title) { _, _ in
                    if !hasEditedTitle {
                        hasEditedTitle = true
                    }
                    clearTitleError()
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.titleField)

            if showValidationErrors, let error = titleError {
                validationErrorRow(message: error.message)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Content")
            TextEditor(text: $content)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.contentField)

            Text("Optional extended content for this note.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var spreadSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Spread")
            Button {
                isShowingSpreadPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select from existing spreads")
                        Text("Or choose a custom date below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.spreadPickerButton)
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Period")
            Picker("Period", selection: $selectedPeriod) {
                ForEach(NoteCreationConfiguration.assignablePeriods, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.NoteCreationSheet.periodSegment(
                                period.rawValue
                            )
                        )
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.periodPicker)

            Text(periodDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateSection: some View {
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
                    dayPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.datePicker,
                    yearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.yearPicker,
                    monthPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthPicker,
                    monthYearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthYearPicker
                )
            )

            if showValidationErrors, let error = dateError {
                validationErrorRow(message: error.message)
            }
        }
    }

    private func validationErrorRow(message: String) -> some View {
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

    // MARK: - Period Description

    private var periodDescription: String {
        switch selectedPeriod {
        case .year:
            return "Note will be assigned to a year spread"
        case .month:
            return "Note will be assigned to a month spread"
        case .day:
            return "Note will be assigned to a day spread"
        case .multiday:
            return "Note will be assigned to a day spread"
        }
    }

    // MARK: - Actions

    private func adjustDateForPeriod(_ period: Period) {
        let minDate = configuration.minimumDate(for: period)
        let normalizedSelected = period.normalizeDate(selectedDate, calendar: presentedTemporalContext.calendar)

        if normalizedSelected < minDate {
            selectedDate = minDate
        }
    }

    private func clearTitleError() {
        if showValidationErrors {
            titleError = nil
        }
    }

    private func clearDateError() {
        if showValidationErrors {
            dateError = nil
        }
    }

    private func attemptCreate() {
        let titleResult = configuration.validateTitle(title)
        let dateResult = configuration.validateDate(period: selectedPeriod, date: selectedDate)

        if !titleResult.isValid || !dateResult.isValid {
            showValidationErrors = true
            titleError = titleResult.error
            dateError = dateResult.error
            return
        }

        createNote()
    }

    private func createNote() {
        isCreating = true

        Task {
            do {
                let note = try await journalManager.addNote(
                    title: title,
                    content: content,
                    date: selectedDate,
                    period: selectedPeriod
                )
                await MainActor.run {
                    onNoteCreated(note)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Create Note") {
    NoteCreationSheet(
        journalManager: .previewInstance,
        selectedSpread: nil,
        onNoteCreated: { note in
            print("Created note: \(note.title)")
        }
    )
}

#Preview("With Selected Spread") {
    let calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }()

    let spread = DataModel.Spread(period: .month, date: Date(), calendar: calendar)

    return NoteCreationSheet(
        journalManager: .previewInstance,
        selectedSpread: spread,
        onNoteCreated: { note in
            print("Created note: \(note.title)")
        }
    )
}
