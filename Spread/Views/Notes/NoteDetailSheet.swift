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

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// The note being edited.
    let note: DataModel.Note

    /// The journal manager for persistence operations.
    @Bindable var journalManager: JournalManager

    /// Callback when the note is deleted.
    let onDelete: () -> Void
    private let presentedTemporalContext: PresentedTemporalContext

    // MARK: - State

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedPeriod: Period = .day
    @State private var selectedDate: Date = Date()
    @State private var isSaving = false

    init(
        note: DataModel.Note,
        journalManager: JournalManager,
        onDelete: @escaping () -> Void
    ) {
        self.note = note
        self.journalManager = journalManager
        self.onDelete = onDelete
        self.presentedTemporalContext = PresentedTemporalContext(journalManager: journalManager)
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
        _selectedPeriod = State(initialValue: note.period)
        _selectedDate = State(initialValue: note.date)
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
                    .disabled(isSaving || title.isEmpty || title.allSatisfy(\.isWhitespace))
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.saveButton)
                }
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
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.titleField)
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
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.NoteDetailSheet.contentField)
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Period")
            Picker("Period", selection: $selectedPeriod) {
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
                calendar: presentedTemporalContext.calendar,
                today: presentedTemporalContext.today
            )
            PeriodDatePicker(
                period: selectedPeriod,
                selectedDate: $selectedDate,
                calendar: presentedTemporalContext.calendar,
                today: presentedTemporalContext.today,
                minimumDate: configuration.minimumDate(for: .day),
                maximumDate: configuration.maximumDate,
                accessibilityIdentifiers: nil
            )
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

    private func formatAssignmentDate(_ assignment: NoteAssignment) -> String {
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

    private func save() {
        isSaving = true

        Task { @MainActor in
            do {
                // Apply title and content changes
                if title != note.title || content != note.content {
                    try await journalManager.updateNoteTitle(note, newTitle: title, newContent: content)
                }

                // Apply date/period changes
                if selectedDate != note.date || selectedPeriod != note.period {
                    try await journalManager.updateNoteDateAndPeriod(
                        note,
                        newDate: selectedDate,
                        newPeriod: selectedPeriod
                    )
                }

                dismiss()
            } catch {
                isSaving = false
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
            NoteAssignment(period: .month, date: Date(), status: .active)
        ]
    )

    NoteDetailSheet(
        note: note,
        journalManager: .previewInstance,
        onDelete: {}
    )
}
