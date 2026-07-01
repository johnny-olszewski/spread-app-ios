import SwiftUI

/// Modal sheet for editing an existing note.
///
/// Supports editing:
/// - Title
/// - Content (multiline)
/// - Period and date
/// - Assignment history (visible in conventional mode)
/// - Delete action
struct NoteDetailSheet: View {

    // MARK: - ViewModel

    @Observable @MainActor final class ViewModel {
        var presentedTemporalContext: PresentedTemporalContext
        var formModel: NoteEditorFormModel
        var isSaving = false
        var isShowingSpreadPicker = false
        var isCreatingList = false
        var newListName = ""
        var isCreatingTag = false
        var newTagName = ""
        var isTagsExpanded = false

        init(note: DataModel.Note, journalManager: JournalManager) {
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

    /// The note being edited.
    let note: DataModel.Note

    /// The journal manager for persistence operations.
    @Bindable var journalManager: JournalManager

    /// Callback when the note is deleted.
    let onDelete: () -> Void

    @State private var viewModel: ViewModel

    init(
        note: DataModel.Note,
        journalManager: JournalManager,
        onDelete: @escaping () -> Void
    ) {
        self.note = note
        self.journalManager = journalManager
        self.onDelete = onDelete
        _viewModel = State(initialValue: ViewModel(note: note, journalManager: journalManager))
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
                    metadataSection
                    EntrySheetDivider()
                    spreadSelectionSection
                    EntrySheetDivider()
                    periodSection
                    EntrySheetDivider()
                    dateSection

                    if !note.migrationHistory.isEmpty || !note.currentAssignments.isEmpty {
                        EntrySheetDivider()
                        assignmentHistorySection
                    }

                    EntrySheetDivider()
                    deleteSection
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
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(
                        viewModel.isSaving ||
                        viewModel.formModel.title.isEmpty ||
                        viewModel.formModel.title.allSatisfy(\.isWhitespace) ||
                        (viewModel.formModel.selectedPeriod == .multiday && viewModel.formModel.selectedSpreadID == nil)
                    )
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.saveButton)
                }
            }
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
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.titleField)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Metadata")
            listPickerRow
            tagsPickerSection
        }
        .alert("New List", isPresented: $viewModel.isCreatingList) {
            TextField("List name", text: $viewModel.newListName)
            Button("Create") { createList() }
            Button("Cancel", role: .cancel) { viewModel.newListName = "" }
        }
        .alert("New Tag", isPresented: $viewModel.isCreatingTag) {
            TextField("Tag name", text: $viewModel.newTagName)
            Button("Create") { createTag() }
            Button("Cancel", role: .cancel) { viewModel.newTagName = "" }
        }
    }

    private var listPickerRow: some View {
        Menu {
            Button("None") { viewModel.formModel.selectedList = nil }
            Divider()
            ForEach(journalManager.lists) { list in
                Button {
                    viewModel.formModel.selectedList =
                        viewModel.formModel.selectedList?.id == list.id ? nil : list
                } label: {
                    if viewModel.formModel.selectedList?.id == list.id {
                        Label {
                            Text(list.name)
                        } icon: {
                            SpreadTheme.Icon.checkmark.sized(SpreadTheme.IconSize.small)
                        }
                    } else {
                        Text(list.name)
                    }
                }
            }
            Divider()
            Button("New List…") { viewModel.isCreatingList = true }
        } label: {
            EntrySheetSelectionSummaryRow(
                title: "List",
                value: viewModel.formModel.selectedList?.name ?? "None",
                isEnabled: true
            )
        }
    }

    private var tagsPickerSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isTagsExpanded) {
            ForEach(journalManager.tags) { tag in
                let isSelected = viewModel.formModel.selectedTagIDs.contains(tag.id)
                let atLimit = viewModel.formModel.selectedTagIDs.count >= 5
                Button {
                    if isSelected {
                        viewModel.formModel.selectedTagIDs.remove(tag.id)
                    } else if !atLimit {
                        viewModel.formModel.selectedTagIDs.insert(tag.id)
                    }
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        if isSelected {
                            SpreadTheme.Icon.checkmark.sized(SpreadTheme.IconSize.small).iconTint(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isSelected && atLimit)
            }
            if viewModel.formModel.selectedTagIDs.count >= 5 {
                Text("Maximum 5 tags")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("New Tag…") { viewModel.isCreatingTag = true }
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack {
                Text("Tags")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(tagsSummary)
                    .foregroundStyle(.primary)
            }
            .font(SpreadTheme.Typography.subheadline)
        }
    }

    private var tagsSummary: String {
        let selected = journalManager.tags.filter { viewModel.formModel.selectedTagIDs.contains($0.id) }
        if selected.isEmpty { return "None" }
        return selected.map(\.name).sorted().joined(separator: ", ")
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
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.contentField)
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
                        Text("Select destination")
                        Text(viewModel.formModel.selectedPeriod == .multiday ? selectedMultidaySummary : "Or use the controls below")
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
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.periodPicker)
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
                    accessibilityIdentifiers: nil
                )
            }
        }
    }

    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Assignment History")
            ForEach(note.migrationHistory + note.currentAssignments, id: \.self) { assignment in
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

    private var deleteSection: some View {
        Button(role: .destructive) {
            deleteNote()
        } label: {
            HStack {
                SpreadTheme.Icon.trash.sized(SpreadTheme.IconSize.medium)
                    .iconTint(.red)
                Text("Delete Note")
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.deleteButton)
    }

    // MARK: - Helpers

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

    private var selectedMultidaySummary: String {
        guard let spreadID = viewModel.formModel.selectedSpreadID,
              let spread = journalManager.spreads.first(where: { $0.id == spreadID }) else {
            return "Select an existing multiday spread"
        }

        return SpreadPickerConfiguration(
            spreads: journalManager.spreads,
            calendar: viewModel.presentedTemporalContext.calendar,
            today: viewModel.presentedTemporalContext.today
        )
        .displayLabel(for: spread)
    }

    // MARK: - Actions

    private func save() {
        viewModel.isSaving = true

        Task { @MainActor in
            do {
                if viewModel.formModel.title != note.title || viewModel.formModel.content != note.content {
                    try await journalManager.updateNoteTitle(
                        note,
                        newTitle: viewModel.formModel.title,
                        newContent: viewModel.formModel.content
                    )
                }

                if viewModel.formModel.selectedDate != note.date || viewModel.formModel.selectedPeriod != note.period {
                    try await journalManager.updateNoteDateAndPeriod(
                        note,
                        newDate: viewModel.formModel.selectedDate,
                        newPeriod: viewModel.formModel.selectedPeriod,
                        preferredSpreadID: viewModel.formModel.selectedSpreadID
                    )
                }

                let selectedTags = journalManager.tags.filter { viewModel.formModel.selectedTagIDs.contains($0.id) }
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
                viewModel.isSaving = false
            }
        }
    }

    private func createList() {
        let name = viewModel.newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.newListName = ""
        guard !name.isEmpty else { return }
        Task { @MainActor in
            if let list = try? await journalManager.createList(name: name) {
                viewModel.formModel.selectedList = list
            }
        }
    }

    private func createTag() {
        let name = viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.newTagName = ""
        guard !name.isEmpty, viewModel.formModel.selectedTagIDs.count < 5 else { return }
        Task { @MainActor in
            if let tag = try? await journalManager.createTag(name: name) {
                viewModel.formModel.selectedTagIDs.insert(tag.id)
            }
        }
    }

    private func deleteNote() {
        Task { @MainActor in
            try? await journalManager.deleteNote(note)
            onDelete()
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    let note = DataModel.Note(
        title: "Meeting notes",
        content: "Discussed project timeline and deliverables.\nAction items assigned.",
        currentAssignments: [
            Assignment(period: .month, date: Date(), status: .active)
        ]
    )

    NoteDetailSheet(
        note: note,
        journalManager: .previewInstance,
        onDelete: {}
    )
}
