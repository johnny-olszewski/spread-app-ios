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
        var title: String
        var content: String
        var selectedPeriod: Period
        var selectedDate: Date
        var selectedSpreadID: UUID?
        var selectedList: DataModel.List?
        var selectedTagIDs: Set<UUID>
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
            title = note.title
            content = note.content
            selectedPeriod = note.period
            selectedDate = note.date ?? note.createdDate
            selectedSpreadID = note.assignments.first(where: {
                $0.status != .migrated && $0.period == .multiday
            })?.spreadID
            selectedList = note.list
            selectedTagIDs = Set(note.tags.map(\.id))
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
                    compactDivider
                    contentSection
                    compactDivider
                    metadataSection
                    compactDivider
                    spreadSelectionSection
                    compactDivider
                    periodSection
                    compactDivider
                    dateSection

                    if !note.assignments.isEmpty {
                        compactDivider
                        assignmentHistorySection
                    }

                    compactDivider
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
                    focusDate: viewModel.selectedDate,
                    onSpreadSelected: { selection in
                        viewModel.selectedPeriod = selection.period
                        viewModel.selectedDate = selection.date
                        viewModel.selectedSpreadID = selection.spreadID
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
                        viewModel.title.isEmpty ||
                        viewModel.title.allSatisfy(\.isWhitespace) ||
                        (viewModel.selectedPeriod == .multiday && viewModel.selectedSpreadID == nil)
                    )
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.saveButton)
                }
            }
            .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                if newPeriod != .multiday {
                    viewModel.selectedSpreadID = nil
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
            sectionHeader("Title")
            TextField("Note title", text: $viewModel.title)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.titleField)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Metadata")
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
            Button("None") { viewModel.selectedList = nil }
            Divider()
            ForEach(journalManager.lists) { list in
                Button {
                    viewModel.selectedList =
                        viewModel.selectedList?.id == list.id ? nil : list
                } label: {
                    if viewModel.selectedList?.id == list.id {
                        Label(list.name, systemImage: "checkmark")
                    } else {
                        Text(list.name)
                    }
                }
            }
            Divider()
            Button("New List…") { viewModel.isCreatingList = true }
        } label: {
            noteSelectionRow(
                title: "List",
                value: viewModel.selectedList?.name ?? "None"
            )
        }
    }

    private var tagsPickerSection: some View {
        DisclosureGroup(isExpanded: $viewModel.isTagsExpanded) {
            ForEach(journalManager.tags) { tag in
                let isSelected = viewModel.selectedTagIDs.contains(tag.id)
                let atLimit = viewModel.selectedTagIDs.count >= 5
                Button {
                    if isSelected {
                        viewModel.selectedTagIDs.remove(tag.id)
                    } else if !atLimit {
                        viewModel.selectedTagIDs.insert(tag.id)
                    }
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isSelected && atLimit)
            }
            if viewModel.selectedTagIDs.count >= 5 {
                Text("Maximum 5 tags")
                    .font(.caption)
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
            .font(.subheadline)
        }
    }

    private var tagsSummary: String {
        let selected = journalManager.tags.filter { viewModel.selectedTagIDs.contains($0.id) }
        if selected.isEmpty { return "None" }
        return selected.map(\.name).sorted().joined(separator: ", ")
    }

    private func noteSelectionRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
        )
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Content")
            TextEditor(text: $viewModel.content)
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
            sectionHeader("Spread")
            Button {
                viewModel.isShowingSpreadPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select destination")
                        Text(viewModel.selectedPeriod == .multiday ? selectedMultidaySummary : "Or use the controls below")
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
            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(NoteCreationConfiguration.assignablePeriods, id: \.self) { period in
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
            sectionHeader("Date")
            let configuration = NoteCreationConfiguration(
                calendar: viewModel.presentedTemporalContext.calendar,
                today: viewModel.presentedTemporalContext.today
            )
            if viewModel.selectedPeriod == .multiday {
                Text(selectedMultidaySummary)
                    .font(.subheadline)
                    .foregroundStyle(viewModel.selectedSpreadID == nil ? .secondary : .primary)
            } else {
                PeriodDatePicker(
                    period: viewModel.selectedPeriod,
                    selectedDate: $viewModel.selectedDate,
                    calendar: viewModel.presentedTemporalContext.calendar,
                    today: viewModel.presentedTemporalContext.today,
                    minimumDate: configuration.minimumDate(for: .day),
                    maximumDate: configuration.maximumDate,
                    accessibilityIdentifiers: nil
                )
            }
        }
    }

    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Assignment History")
            ForEach(note.assignments, id: \.self) { assignment in
                HStack {
                    Image(systemName: assignment.status == .active ? "checkmark.circle" : "arrow.right.circle")
                        .foregroundStyle(assignment.status == .active ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.period.displayName)
                            .font(.subheadline)
                        Text(formatAssignmentDate(assignment))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(assignment.status == .active ? "Active" : "Migrated")
                        .font(.caption)
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
                Image(systemName: "trash")
                Text("Delete Note")
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.deleteButton)
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
        guard let spreadID = viewModel.selectedSpreadID,
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
                if viewModel.title != note.title || viewModel.content != note.content {
                    try await journalManager.updateNoteTitle(note, newTitle: viewModel.title, newContent: viewModel.content)
                }

                if viewModel.selectedDate != note.date || viewModel.selectedPeriod != note.period {
                    try await journalManager.updateNoteDateAndPeriod(
                        note,
                        newDate: viewModel.selectedDate,
                        newPeriod: viewModel.selectedPeriod,
                        preferredSpreadID: viewModel.selectedSpreadID
                    )
                }

                let selectedTags = journalManager.tags.filter { viewModel.selectedTagIDs.contains($0.id) }
                let metadataChanged =
                    viewModel.selectedList?.id != note.list?.id ||
                    Set(selectedTags.map(\.id)) != Set(note.tags.map(\.id))
                if metadataChanged {
                    try await journalManager.updateNoteMetadata(
                        note,
                        list: viewModel.selectedList,
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
                viewModel.selectedList = list
            }
        }
    }

    private func createTag() {
        let name = viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.newTagName = ""
        guard !name.isEmpty, viewModel.selectedTagIDs.count < 5 else { return }
        Task { @MainActor in
            if let tag = try? await journalManager.createTag(name: name) {
                viewModel.selectedTagIDs.insert(tag.id)
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
        assignments: [
            Assignment(period: .month, date: Date(), status: .active)
        ]
    )

    NoteDetailSheet(
        note: note,
        journalManager: .previewInstance,
        onDelete: {}
    )
}
