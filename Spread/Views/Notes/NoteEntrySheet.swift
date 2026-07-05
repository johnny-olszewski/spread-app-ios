import SwiftUI

/// Unified sheet for Note creation and editing, built on the generic `EntrySheet` shell.
///
/// Replaces `NoteCreationSheet` (create mode) and `NoteDetailSheet` (edit mode).
/// All Note-specific section content (title, content, metadata, assignment) lives here;
/// chrome (toolbar, loading overlay, delete confirmation, history section)
/// is delegated to `EntrySheet`.
struct NoteEntrySheet: View {

    // MARK: - ViewModel

    @Observable @MainActor final class ViewModel {
        let mode: EntrySheetMode
        var presentedTemporalContext: PresentedTemporalContext
        var formModel: NoteEditorFormModel
        var isBusy = false
        var errorMessage: String?

        /// Create-mode initializer.
        init(journalManager: JournalManager, selectedSpread: DataModel.Spread?) {
            mode = .create
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context
            let configuration = EntryCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            formModel = NoteEditorFormModel(configuration: configuration, selectedSpread: selectedSpread)
        }

        /// Edit-mode initializer.
        init(note: DataModel.Note, journalManager: JournalManager) {
            mode = .edit
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context
            let configuration = EntryCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            formModel = NoteEditorFormModel(configuration: configuration, note: note)
        }
    }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    @Bindable var journalManager: JournalManager

    // MARK: - Mode-specific data

    private let note: DataModel.Note?
    private let onNoteCreated: ((DataModel.Note) -> Void)?
    private let onDelete: (() -> Void)?

    // MARK: - State

    @State private var viewModel: ViewModel
    @FocusState private var isTitleFocused: Bool

    // MARK: - Inits

    /// Create-mode entry point.
    init(
        journalManager: JournalManager,
        selectedSpread: DataModel.Spread?,
        onNoteCreated: @escaping (DataModel.Note) -> Void
    ) {
        self.journalManager = journalManager
        self.note = nil
        self.onNoteCreated = onNoteCreated
        self.onDelete = nil
        _viewModel = State(initialValue: ViewModel(journalManager: journalManager, selectedSpread: selectedSpread))
    }

    /// Edit-mode entry point.
    init(
        note: DataModel.Note,
        journalManager: JournalManager,
        onDelete: @escaping () -> Void
    ) {
        self.journalManager = journalManager
        self.note = note
        self.onNoteCreated = nil
        self.onDelete = onDelete
        _viewModel = State(initialValue: ViewModel(note: note, journalManager: journalManager))
    }

    // MARK: - Computed Properties

    private var configuration: EntryCreationConfiguration {
        viewModel.formModel.configuration
    }

    private var isSaveEnabled: Bool {
        !viewModel.formModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(viewModel.formModel.selectedPeriod == .multiday && viewModel.formModel.selectedSpreadID == nil)
    }

    // MARK: - Body

    var body: some View {
        @Bindable var viewModel = viewModel
        EntrySheet(
            navigationTitle: viewModel.mode == .create ? "New Note" : "Edit Note",
            mode: viewModel.mode,
            isBusy: viewModel.isBusy,
            cancelIdentifier: viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.NoteCreationSheet.cancelButton
                : Definitions.AccessibilityIdentifiers.NoteDetailSheet.cancelButton,
            primaryIdentifier: viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.NoteCreationSheet.createButton
                : Definitions.AccessibilityIdentifiers.NoteDetailSheet.saveButton,
            onCancel: { dismiss() },
            onPrimary: { viewModel.mode == .create ? attemptCreate() : save() },
            isPrimaryVisible: viewModel.formModel.isCreateButtonVisible,
            isSaveEnabled: isSaveEnabled,
            historySection: historyAnyView,
            deleteAction: note != nil ? { deleteNote() } : nil,
            deleteAlertTitle: "Delete Note",
            deleteAlertMessage: "Are you sure you want to delete this note? This action cannot be undone.",
            deleteButtonIdentifier: Definitions.AccessibilityIdentifiers.NoteDetailSheet.deleteButton,
            errorMessage: Binding(
                get: { viewModel.errorMessage },
                set: { viewModel.errorMessage = $0 }
            )
        ) {
            titleSection
            EntrySheetDivider()
            contentSection
            EntrySheetDivider()
            listSection
            tagsSection
            EntrySheetDivider()
            assignmentSection
        }
        .onAppear {
            if viewModel.mode == .create {
                isTitleFocused = true
            }
        }
        .localhostTemporalHarness(
            presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics(
                calendarIdentifier: viewModel.presentedTemporalContext.calendar.identifier,
                today: viewModel.presentedTemporalContext.today
            )
        )
    }

    // MARK: - Optional edit-mode section injection

    private var historyAnyView: AnyView? {
        guard let note, (!note.migrationHistory.isEmpty || !note.currentAssignments.isEmpty) else {
            return nil
        }
        return AnyView(assignmentHistorySection)
    }

    // MARK: - Sections

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Title")
            TextField("Note title", text: $viewModel.formModel.title)
                .focused($isTitleFocused)
                .onChange(of: viewModel.formModel.title) { _, _ in
                    viewModel.formModel.handleTitleChange()
                }
                .accessibilityIdentifier(viewModel.mode == .create
                    ? Definitions.AccessibilityIdentifiers.NoteCreationSheet.titleField
                    : Definitions.AccessibilityIdentifiers.NoteDetailSheet.titleField
                )

            if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.titleError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Content")
            TextEditor(text: $viewModel.formModel.content)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .background(SpreadTheme.Paper.secondary)
                .clipShape(RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.standard, style: .continuous))
                .accessibilityIdentifier(viewModel.mode == .create
                    ? Definitions.AccessibilityIdentifiers.NoteCreationSheet.contentField
                    : Definitions.AccessibilityIdentifiers.NoteDetailSheet.contentField
                )

            if viewModel.mode == .create {
                Text("Optional extended content for this note.")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "List")

            EntrySheetChipCloud(
                chips: journalManager.lists.map { list in
                    .init(
                        id: list.id,
                        title: list.name,
                        isSelected: viewModel.formModel.selectedList?.id == list.id
                    )
                },
                onChipTapped: { id in
                    if viewModel.formModel.selectedList?.id == id {
                        viewModel.formModel.selectedList = nil
                    } else {
                        viewModel.formModel.selectedList = journalManager.lists.first { $0.id == id }
                    }
                },
                creationPlaceholder: "List name",
                onCreate: { createList(named: $0) }
            )
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        let atLimit = viewModel.formModel.selectedTagIDs.count >= 5
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Tags")

            EntrySheetChipCloud(
                chips: journalManager.tags.map { tag in
                    let isSelected = viewModel.formModel.selectedTagIDs.contains(tag.id)
                    return .init(
                        id: tag.id,
                        title: tag.name,
                        isSelected: isSelected,
                        isDisabled: !isSelected && atLimit
                    )
                },
                onChipTapped: { id in
                    if viewModel.formModel.selectedTagIDs.contains(id) {
                        viewModel.formModel.selectedTagIDs.remove(id)
                    } else if !atLimit {
                        viewModel.formModel.selectedTagIDs.insert(id)
                    }
                },
                creationPlaceholder: atLimit ? nil : "Tag name",
                onCreate: atLimit ? nil : { createTag(named: $0) }
            )

            if atLimit {
                Text("Maximum 5 tags")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Assignment")

            periodSection
            dateSection
        }
    }

    @ViewBuilder
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Period")

            EntrySheetChoiceRow(
                options: EntryCreationConfiguration.assignablePeriods.map { period in
                    .init(
                        value: period,
                        title: period.displayName,
                        accessibilityIdentifier: viewModel.mode == .create
                            ? Definitions.AccessibilityIdentifiers.NoteCreationSheet.periodSegment(period.rawValue)
                            : nil
                    )
                },
                selection: viewModel.formModel.selectedPeriod,
                onSelect: { viewModel.formModel.setPeriod($0) }
            )
            .accessibilityIdentifier(viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.NoteCreationSheet.periodPicker
                : Definitions.AccessibilityIdentifiers.NoteDetailSheet.periodPicker
            )

            Text(viewModel.formModel.periodDescription)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var dateSection: some View {
        let isMultiday = viewModel.formModel.selectedPeriod == .multiday
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: isMultiday ? "Spread" : "Date")

            if isMultiday {
                Text(selectedMultidaySummary)
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(viewModel.formModel.selectedSpreadID == nil ? .secondary : .primary)
            }

            PeriodDatePicker(
                period: viewModel.formModel.selectedPeriod,
                selectedDate: $viewModel.formModel.selectedDate,
                calendar: viewModel.presentedTemporalContext.calendar,
                today: viewModel.presentedTemporalContext.today,
                minimumDate: configuration.minimumDate(for: .day),
                maximumDate: configuration.maximumDate,
                accessibilityIdentifiers: viewModel.mode == .create
                    ? .init(
                        dayPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.datePicker,
                        yearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.yearPicker,
                        monthPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthPicker,
                        monthYearPicker: Definitions.AccessibilityIdentifiers.NoteCreationSheet.monthYearPicker
                    )
                    : nil,
                spreadContext: .init(
                    spreads: journalManager.spreads,
                    selectedSpreadID: viewModel.formModel.selectedSpreadID,
                    onMultidaySpreadSelected: { spread in
                        viewModel.formModel.applySpreadSelection(SpreadPickerSelection(
                            period: .multiday,
                            date: spread.startDate ?? spread.date,
                            spreadID: spread.id
                        ))
                    }
                )
            )

            if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.dateError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Assignment History")
            ForEach(note!.migrationHistory + note!.currentAssignments, id: \.self) { assignment in
                HStack {
                    (assignment.status == .active ? SpreadTheme.Icon.checkCircle : SpreadTheme.Icon.arrowRightCircle)
                        .sized(SpreadTheme.IconSize.medium)
                        .iconTint(assignment.status == .active ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.period.displayName)
                            .font(SpreadTheme.Typography.subheadline)
                        Text(formatAssignmentDate(assignment))
                            .font(SpreadTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(assignment.status == .active ? "Active" : "Migrated")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Helpers

    private var selectedMultidaySummary: String {
        guard let spreadID = viewModel.formModel.selectedSpreadID,
              let spread = journalManager.spreads.first(where: { $0.id == spreadID }) else {
            return "Tap a multiday spread’s coverage bar on the calendar"
        }
        return SpreadPickerConfiguration(
            spreads: journalManager.spreads,
            calendar: viewModel.presentedTemporalContext.calendar,
            today: viewModel.presentedTemporalContext.today
        )
        .displayLabel(for: spread)
    }

    private func formatAssignmentDate(_ assignment: Assignment) -> String {
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.timeZone = journalManager.calendar.timeZone
        switch assignment.period {
        case .year:
            formatter.dateFormat = "yyyy"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .day, .multiday:
            formatter.dateStyle = .medium
        }
        return formatter.string(from: assignment.date)
    }

    // MARK: - Actions

    private func attemptCreate() {
        guard viewModel.formModel.validateForSubmission() else { return }
        viewModel.isBusy = true
        Task {
            do {
                let note = try await journalManager.addNote(
                    title: viewModel.formModel.title,
                    content: viewModel.formModel.sanitizedContent ?? "",
                    date: viewModel.formModel.effectiveSelectedDate,
                    period: viewModel.formModel.selectedPeriod,
                    preferredSpreadID: viewModel.formModel.selectedSpreadID
                )
                await MainActor.run {
                    onNoteCreated?(note)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    viewModel.isBusy = false
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func save() {
        guard let note else { return }
        viewModel.isBusy = true
        Task { @MainActor in
            do {
                let contentChanged = viewModel.formModel.title != note.title ||
                    (viewModel.formModel.sanitizedContent ?? "") != note.content
                if contentChanged {
                    try await journalManager.updateNoteTitle(
                        note,
                        newTitle: viewModel.formModel.title,
                        newContent: viewModel.formModel.sanitizedContent ?? ""
                    )
                }

                let effectiveDate = viewModel.formModel.effectiveSelectedDate
                if note.date == nil ||
                   effectiveDate != note.date ||
                   viewModel.formModel.selectedPeriod != note.period ||
                   viewModel.formModel.selectedSpreadID != note.currentAssignments.first(where: { $0.period == .multiday })?.spreadID {
                    try await journalManager.updateNoteDateAndPeriod(
                        note,
                        newDate: effectiveDate,
                        newPeriod: viewModel.formModel.selectedPeriod,
                        preferredSpreadID: viewModel.formModel.selectedSpreadID
                    )
                }

                let selectedTags = journalManager.tags.filter {
                    viewModel.formModel.selectedTagIDs.contains($0.id)
                }
                let metadataChanged =
                    viewModel.formModel.selectedList?.id != note.list?.id ||
                    Set(selectedTags.map(\.id)) != Set(note.tags.map(\.id))
                if metadataChanged {
                    try await journalManager.updateNoteMetadata(
                        note,
                        list: viewModel.formModel.selectedList,
                        tags: selectedTags
                    )
                }

                dismiss()
            } catch {
                viewModel.isBusy = false
            }
        }
    }

    /// Creates a list from the chip cloud’s inline creation field and selects it.
    private func createList(named name: String) {
        Task { @MainActor in
            if let list = try? await journalManager.createList(name: name) {
                viewModel.formModel.selectedList = list
            }
        }
    }

    /// Creates a tag from the chip cloud’s inline creation field and selects it.
    private func createTag(named name: String) {
        guard viewModel.formModel.selectedTagIDs.count < 5 else { return }
        Task { @MainActor in
            if let tag = try? await journalManager.createTag(name: name) {
                viewModel.formModel.selectedTagIDs.insert(tag.id)
            }
        }
    }

    private func deleteNote() {
        guard let note else { return }
        Task { @MainActor in
            try? await journalManager.deleteNote(note)
            onDelete?()
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Create Note") {
    NoteEntrySheet(
        journalManager: .previewInstance,
        selectedSpread: nil,
        onNoteCreated: { _ in }
    )
}

#Preview("Edit Note") {
    let note = DataModel.Note(
        title: "Meeting notes",
        content: "Discussed project timeline and deliverables.\nAction items assigned.",
        currentAssignments: [
            Assignment(period: .month, date: Date(), status: .active)
        ]
    )
    NoteEntrySheet(
        note: note,
        journalManager: .previewInstance,
        onDelete: {}
    )
}
