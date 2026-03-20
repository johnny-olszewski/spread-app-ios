import SwiftUI

/// Modal sheet for editing an existing task.
///
/// Supports editing:
/// - Title
/// - Status (open/complete/migrated/cancelled)
/// - Period and date
/// - Assignment history (visible in conventional mode)
/// - Delete action with confirmation
struct TaskDetailSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// The task being edited.
    let task: DataModel.Task

    /// The journal manager for persistence operations.
    @Bindable var journalManager: JournalManager

    /// Callback when the task is deleted.
    let onDelete: () -> Void

    // MARK: - State

    @State private var title: String = ""
    @State private var selectedStatus: DataModel.Task.Status = .open
    @State private var selectedPeriod: Period = .day
    @State private var selectedDate: Date = Date()
    @State private var isSaving = false
    @State private var isShowingDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    titleSection
                    compactDivider
                    statusSection
                    compactDivider
                    periodSection
                    compactDivider
                    dateSection

                    if !task.assignments.isEmpty {
                        compactDivider
                        assignmentHistorySection
                    }

                    compactDivider
                    deleteSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isSaving || title.isEmpty || title.allSatisfy(\.isWhitespace))
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton)
                }
            }
            .alert("Delete Task", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
            .onAppear {
                title = task.title
                selectedStatus = task.status
                selectedPeriod = task.period
                selectedDate = task.date
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Title")
            TextField("Task title", text: $title)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.titleField)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Status")
            Picker("Status", selection: $selectedStatus) {
                ForEach(DataModel.Task.Status.allCases, id: \.self) { status in
                    Text(statusDisplayName(status))
                        .tag(status)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker)
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Period")
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TaskCreationConfiguration.assignablePeriods, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodPicker)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Date")
            let configuration = TaskCreationConfiguration(
                calendar: journalManager.calendar,
                today: journalManager.today
            )
            PeriodDatePicker(
                period: selectedPeriod,
                selectedDate: $selectedDate,
                calendar: journalManager.calendar,
                today: journalManager.today,
                minimumDate: configuration.minimumDate(for: .day),
                maximumDate: configuration.maximumDate,
                accessibilityIdentifiers: nil
            )
        }
    }

    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Assignment History")
            ForEach(task.assignments, id: \.self) { assignment in
                HStack {
                    Image(systemName: assignmentIcon(for: assignment.status))
                        .foregroundStyle(assignmentColor(for: assignment.status))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.period.displayName)
                            .font(.subheadline)
                        Text(formatAssignmentDate(assignment))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(assignmentStatusLabel(for: assignment.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Task")
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.deleteButton)
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

    private func statusDisplayName(_ status: DataModel.Task.Status) -> String {
        switch status {
        case .open: "Open"
        case .complete: "Complete"
        case .migrated: "Migrated"
        case .cancelled: "Cancelled"
        }
    }

    private func assignmentIcon(for status: DataModel.Task.Status) -> String {
        switch status {
        case .open: "circle"
        case .complete: "checkmark.circle"
        case .migrated: "arrow.right.circle"
        case .cancelled: "xmark.circle"
        }
    }

    private func assignmentColor(for status: DataModel.Task.Status) -> Color {
        switch status {
        case .open: .primary
        case .complete: .green
        case .migrated: .orange
        case .cancelled: .secondary
        }
    }

    private func assignmentStatusLabel(for status: DataModel.Task.Status) -> String {
        switch status {
        case .open: "Open"
        case .complete: "Complete"
        case .migrated: "Migrated"
        case .cancelled: "Cancelled"
        }
    }

    private func formatAssignmentDate(_ assignment: TaskAssignment) -> String {
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

        Task {
            do {
                if title != task.title {
                    try await journalManager.updateTaskTitle(task, newTitle: title)
                }

                if selectedStatus != task.status {
                    try await journalManager.updateTaskStatus(task, newStatus: selectedStatus)
                }

                if selectedDate != task.date || selectedPeriod != task.period {
                    try await journalManager.updateTaskDateAndPeriod(
                        task,
                        newDate: selectedDate,
                        newPeriod: selectedPeriod
                    )
                }

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }

    private func deleteTask() {
        Task {
            try? await journalManager.deleteTask(task)
            await MainActor.run {
                onDelete()
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let task = DataModel.Task(
        title: "Review project timeline",
        status: .open,
        assignments: [
            TaskAssignment(period: .month, date: Date(), status: .open)
        ]
    )

    TaskDetailSheet(
        task: task,
        journalManager: .previewInstance,
        onDelete: {}
    )
}
