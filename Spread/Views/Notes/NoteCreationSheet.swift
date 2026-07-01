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

    // MARK: - ViewModel

    @Observable @MainActor final class ViewModel {
        var presentedTemporalContext: PresentedTemporalContext
        var title: String = ""
        var content: String = ""
        var selectedPeriod: Period
        var selectedDate: Date
        var selectedSpreadID: UUID?
        var hasEditedTitle = false
        var showValidationErrors = false
        var isCreating = false
        var titleError: NoteCreationError?
        var dateError: NoteCreationError?
        var isShowingSpreadPicker = false

        init(journalManager: JournalManager, selectedSpread: DataModel.Spread?) {
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context

            let configuration = NoteCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            let defaults = configuration.defaultSelection(from: selectedSpread)
            let minimumDate = configuration.minimumDate(for: defaults.period)
            let normalizedDate = defaults.period.normalizeDate(defaults.date, calendar: context.calendar)
            selectedPeriod = defaults.period
            if defaults.period == .multiday {
                selectedDate = normalizedDate
            } else {
                selectedDate = normalizedDate < minimumDate ? minimumDate : normalizedDate
            }
            selectedSpreadID = selectedSpread?.period == .multiday ? selectedSpread?.id : nil
        }
    }

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

    @State private var viewModel: ViewModel
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    init(
        journalManager: JournalManager,
        selectedSpread: DataModel.Spread?,
        onNoteCreated: @escaping (DataModel.Note) -> Void
    ) {
        self.journalManager = journalManager
        self.selectedSpread = selectedSpread
        self.onNoteCreated = onNoteCreated
        _viewModel = State(initialValue: ViewModel(journalManager: journalManager, selectedSpread: selectedSpread))
    }

    // MARK: - Computed Properties

    private var configuration: NoteCreationConfiguration {
        NoteCreationConfiguration(
            calendar: viewModel.presentedTemporalContext.calendar,
            today: viewModel.presentedTemporalContext.today
        )
    }

    /// Whether the Create button should be visible.
    ///
    /// Hidden until title is edited once; then always visible.
    private var isCreateButtonVisible: Bool {
        viewModel.hasEditedTitle
    }

    // MARK: - Body

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    titleSection
                    EntrySheetDivider()
                    contentSection
                    EntrySheetDivider()
                    spreadSelectionSection
                    EntrySheetDivider()
                    periodSection
                    EntrySheetDivider()
                    dateSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .sheet(isPresented: $viewModel.isShowingSpreadPicker) {
                SpreadPickerView(
                    spreads: journalManager.spreads,
                    calendar: viewModel.presentedTemporalContext.calendar,
                    today: viewModel.presentedTemporalContext.today,
                    focusDate: viewModel.selectedDate,
                    onSpreadSelected: { selection in
                        viewModel.selectedPeriod = selection.period
                        viewModel.selectedDate = selection.date
                        viewModel.selectedSpreadID = selection.spreadID
                        clearDateError()
                    },
                    onChooseCustomDate: {}
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
                        .disabled(viewModel.isCreating)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.createButton)
                    }
                }
            }
            .onAppear { isTitleFocused = true }
            .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                if newPeriod != .multiday {
                    viewModel.selectedSpreadID = nil
                }
                adjustDateForPeriod(newPeriod)
                clearDateError()
            }
        }
        .overlay {
            if viewModel.isCreating {
                EntrySheetLoadingOverlay()
            }
        }
        .interactiveDismissDisabled(isCreateButtonVisible)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .localhostTemporalHarness(
            presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics(
                calendarIdentifier: viewModel.presentedTemporalContext.calendar.identifier,
                today: viewModel.presentedTemporalContext.today
            )
        )
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Title")
            TextField("Note title", text: $viewModel.title)
                .focused($isTitleFocused)
                .onChange(of: viewModel.title) { _, _ in
                    if !viewModel.hasEditedTitle {
                        viewModel.hasEditedTitle = true
                    }
                    clearTitleError()
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.titleField)

            if viewModel.showValidationErrors, let error = viewModel.titleError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Content")
            TextEditor(text: $viewModel.content)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.contentField)

            Text("Optional extended content for this note.")
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var spreadSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Spread")
            Button {
                viewModel.isShowingSpreadPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select from existing spreads")
                        Text("Or choose a custom date below")
                            .font(SpreadTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SpreadTheme.Icon.caretRight.sized(SpreadTheme.IconSize.small)
                        .iconTint(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.spreadPickerButton)
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Period")
            Picker("Period", selection: $viewModel.selectedPeriod) {
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
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Date")
            if viewModel.selectedPeriod == .multiday {
                Text(selectedMultidaySummary)
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(viewModel.selectedSpreadID == nil ? .secondary : .primary)
            } else {
                PeriodDatePicker(
                    period: viewModel.selectedPeriod,
                    selectedDate: $viewModel.selectedDate,
                    calendar: viewModel.presentedTemporalContext.calendar,
                    today: viewModel.presentedTemporalContext.today,
                    minimumDate: configuration.minimumDate(for: .day),
                    maximumDate: configuration.maximumDate,
                    accessibilityIdentifiers: .init(
                        dayPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.datePicker,
                        yearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.yearPicker,
                        monthPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthPicker,
                        monthYearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthYearPicker
                    )
                )
            }

            if viewModel.showValidationErrors, let error = viewModel.dateError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    // MARK: - Period Description

    private var periodDescription: String {
        switch viewModel.selectedPeriod {
        case .year:
            return "Note will be assigned to a year spread"
        case .month:
            return "Note will be assigned to a month spread"
        case .multiday:
            return "Note will be assigned to an existing multiday spread"
        case .day:
            return "Note will be assigned to a day spread"
        }
    }

    // MARK: - Actions

    private func adjustDateForPeriod(_ period: Period) {
        guard period != .multiday else { return }
        let minDate = configuration.minimumDate(for: period)
        let normalizedSelected = period.normalizeDate(viewModel.selectedDate, calendar: viewModel.presentedTemporalContext.calendar)

        if normalizedSelected < minDate {
            viewModel.selectedDate = minDate
        }
    }

    private var selectedMultidaySummary: String {
        guard let spreadID = viewModel.selectedSpreadID,
              let spread = journalManager.spreads.first(where: { $0.id == spreadID }) else {
            return "Select an existing multiday spread above"
        }

        return SpreadPickerConfiguration(
            spreads: journalManager.spreads,
            calendar: viewModel.presentedTemporalContext.calendar,
            today: viewModel.presentedTemporalContext.today
        )
        .displayLabel(for: spread)
    }

    private func clearTitleError() {
        if viewModel.showValidationErrors {
            viewModel.titleError = nil
        }
    }

    private func clearDateError() {
        if viewModel.showValidationErrors {
            viewModel.dateError = nil
        }
    }

    private func attemptCreate() {
        let titleResult = configuration.validateTitle(viewModel.title)
        let dateResult: NoteCreationResult
        if viewModel.selectedPeriod == .multiday && viewModel.selectedSpreadID == nil {
            dateResult = .invalid(.missingMultidaySpread)
        } else if viewModel.selectedPeriod == .multiday {
            dateResult = .valid
        } else {
            dateResult = configuration.validateDate(period: viewModel.selectedPeriod, date: viewModel.selectedDate)
        }

        if !titleResult.isValid || !dateResult.isValid {
            viewModel.showValidationErrors = true
            viewModel.titleError = titleResult.error
            viewModel.dateError = dateResult.error
            return
        }

        createNote()
    }

    private func createNote() {
        viewModel.isCreating = true

        Task {
            do {
                let note = try await journalManager.addNote(
                    title: viewModel.title,
                    content: viewModel.content,
                    date: viewModel.selectedDate,
                    period: viewModel.selectedPeriod,
                    preferredSpreadID: viewModel.selectedSpreadID
                )
                await MainActor.run {
                    onNoteCreated(note)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    viewModel.isCreating = false
                    errorMessage = error.localizedDescription
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
        onNoteCreated: { _ in }
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
        onNoteCreated: { _ in }
    )
}
