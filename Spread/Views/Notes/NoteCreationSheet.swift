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
        var formModel: NoteEditorFormModel
        var isCreating = false
        var isShowingSpreadPicker = false

        init(journalManager: JournalManager, selectedSpread: DataModel.Spread?) {
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context
            let configuration = EntryCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            formModel = NoteEditorFormModel(configuration: configuration, selectedSpread: selectedSpread)
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

    /// Whether the Create button should be visible.
    ///
    /// Hidden until title is edited once; then always visible.
    private var isCreateButtonVisible: Bool {
        viewModel.formModel.isCreateButtonVisible
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
                    focusDate: viewModel.formModel.selectedDate,
                    onSpreadSelected: { selection in
                        viewModel.formModel.applySpreadSelection(selection)
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
            TextField("Note title", text: $viewModel.formModel.title)
                .focused($isTitleFocused)
                .onChange(of: viewModel.formModel.title) { _, _ in
                    viewModel.formModel.handleTitleChange()
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteCreationSheet.titleField)

            if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.titleError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Content")
            TextEditor(text: $viewModel.formModel.content)
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
            Picker("Period", selection: Binding(
                get: { viewModel.formModel.selectedPeriod },
                set: { viewModel.formModel.setPeriod($0) }
            )) {
                ForEach(EntryCreationConfiguration.assignablePeriods, id: \.self) { period in
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

            Text(viewModel.formModel.periodDescription)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Date")
            if viewModel.formModel.selectedPeriod == .multiday {
                Text(selectedMultidaySummary)
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(viewModel.formModel.selectedSpreadID == nil ? .secondary : .primary)
            } else {
                PeriodDatePicker(
                    period: viewModel.formModel.selectedPeriod,
                    selectedDate: $viewModel.formModel.selectedDate,
                    calendar: viewModel.presentedTemporalContext.calendar,
                    today: viewModel.presentedTemporalContext.today,
                    minimumDate: viewModel.formModel.configuration.minimumDate(for: .day),
                    maximumDate: viewModel.formModel.configuration.maximumDate,
                    accessibilityIdentifiers: .init(
                        dayPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.datePicker,
                        yearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.yearPicker,
                        monthPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthPicker,
                        monthYearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthYearPicker
                    )
                )
            }

            if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.dateError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    // MARK: - Helpers

    private var selectedMultidaySummary: String {
        guard let spreadID = viewModel.formModel.selectedSpreadID,
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

    // MARK: - Actions

    private func attemptCreate() {
        guard viewModel.formModel.validateForSubmission() else {
            return
        }
        createNote()
    }

    private func createNote() {
        viewModel.isCreating = true

        Task {
            do {
                let note = try await journalManager.addNote(
                    title: viewModel.formModel.title,
                    content: viewModel.formModel.content,
                    date: viewModel.formModel.effectiveSelectedDate,
                    period: viewModel.formModel.selectedPeriod,
                    preferredSpreadID: viewModel.formModel.selectedSpreadID
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
