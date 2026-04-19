import SwiftUI

/// Modal sheet for editing an existing task.
///
/// The task edit flow keeps lifecycle state and assignment state distinct:
/// - Status changes are draft-only until save.
/// - `.migrated` remains assignment history, not a user-editable task status.
/// - Period/date changes are disabled while the draft task is complete or cancelled.
struct TaskDetailSheet: View {

    @Environment(\.dismiss) private var dismiss

    let task: DataModel.Task
    @Bindable var journalManager: JournalManager
    let onDelete: () -> Void

    @State private var selectedStatus: DataModel.Task.Status = .open
    @State private var formModel: TaskEditorFormModel
    @State private var isSaving = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingSpreadPicker = false

    private var titleBinding: Binding<String> {
        Binding(
            get: { formModel.title },
            set: { formModel.title = $0 }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { formModel.selectedDate },
            set: { formModel.selectedDate = $0 }
        )
    }

    private var assignmentBinding: Binding<Bool> {
        Binding(
            get: { formModel.hasPreferredAssignment },
            set: { formModel.setPreferredAssignmentEnabled($0) }
        )
    }

    private var bodyBinding: Binding<String> {
        Binding(
            get: { formModel.body },
            set: { formModel.body = $0 }
        )
    }

    private var priorityBinding: Binding<DataModel.Task.Priority> {
        Binding(
            get: { formModel.priority },
            set: { formModel.priority = $0 }
        )
    }

    private var dueDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { formModel.hasDueDate },
            set: { formModel.hasDueDate = $0 }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { formModel.dueDate },
            set: { formModel.dueDate = $0.startOfDay(calendar: journalManager.calendar) }
        )
    }

    private var configuration: TaskCreationConfiguration {
        formModel.configuration
    }

    private var isAssignmentEditable: Bool {
        selectedStatus.allowsAssignmentEditingInTaskSheet
    }

    init(
        task: DataModel.Task,
        journalManager: JournalManager,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self.journalManager = journalManager
        self.onDelete = onDelete
        _selectedStatus = State(initialValue: task.status)
        let configuration = TaskCreationConfiguration(
            calendar: journalManager.calendar,
            today: journalManager.today
        )
        _formModel = State(
            initialValue: TaskEditorFormModel(
                configuration: configuration,
                task: task
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    titleSection
                    compactDivider
                    metadataSection
                    compactDivider
                    detailsSection
                    compactDivider
                    assignmentSection

                    if !task.assignments.isEmpty {
                        compactDivider
                        assignmentHistorySection
                    }

                    if let lifecycleActionTitle = selectedStatus.lifecycleActionTitleInTaskSheet,
                       let lifecycleResult = selectedStatus.lifecycleActionResultInTaskSheet,
                       let lifecycleIcon = selectedStatus.lifecycleActionIconInTaskSheet {
                        compactDivider
                        lifecycleSection(
                            title: lifecycleActionTitle,
                            icon: lifecycleIcon,
                            role: selectedStatus.lifecycleActionRoleInTaskSheet,
                            resultStatus: lifecycleResult
                        )
                    }

                    compactDivider
                    deleteSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .sheet(isPresented: $isShowingSpreadPicker) {
                SpreadPickerView(
                    spreads: journalManager.spreads,
                    calendar: journalManager.calendar,
                    today: journalManager.today,
                    onSpreadSelected: { period, date in
                        formModel.applySpreadSelection(period: period, date: date)
                    },
                    onChooseCustomDate: {}
                )
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
                    .disabled(isSaving || formModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Title")
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                TaskStatusToggleButton(
                    status: $selectedStatus,
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusToggle
                )

                TextField("Task title", text: titleBinding)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.titleField)
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Metadata")

            Picker("Priority", selection: priorityBinding) {
                ForEach(DataModel.Task.Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.priorityPicker)

            Toggle("Due date", isOn: dueDateEnabledBinding)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDateToggle)

            if formModel.hasDueDate {
                DatePicker(
                    "Due",
                    selection: dueDateBinding,
                    displayedComponents: .date
                )
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDatePicker)
            }
        }
    }

    private var detailsSection: some View {
        DisclosureGroup("Details", isExpanded: $formModel.isDetailsExpanded) {
            TextEditor(text: bodyBinding)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.bodyField)
        }
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Assignment")

            Toggle("Assign to spread", isOn: assignmentBinding)
                .disabled(!isAssignmentEditable)
                .opacity(isAssignmentEditable ? 1 : 0.7)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.assignmentToggle)

            if formModel.hasPreferredAssignment {
                spreadSelectionSection
                periodSection
                dateSection
            } else {
                Text(formModel.periodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(isAssignmentEditable ? 1 : 0.7)
            }
        }
    }

    private var spreadSelectionSection: some View {
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
        .disabled(!isAssignmentEditable)
        .opacity(isAssignmentEditable ? 1 : 0.7)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.spreadPickerButton)
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Period")

            Menu {
                ForEach(TaskCreationConfiguration.assignablePeriods, id: \.self) { period in
                    Button {
                        formModel.setPeriod(period)
                    } label: {
                        if period == formModel.selectedPeriod {
                            Label(period.displayName, systemImage: "checkmark")
                        } else {
                            Text(period.displayName)
                        }
                    }
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodSegment(period.rawValue)
                    )
                }
            } label: {
                selectionSummaryRow(
                    title: "Period",
                    value: formModel.selectedPeriod.displayName,
                    isEnabled: isAssignmentEditable
                )
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodPicker)
            .disabled(!isAssignmentEditable)

            Text(formModel.periodDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(isAssignmentEditable ? 1 : 0.7)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Date")

            selectionSummaryRow(
                title: "Date",
                value: formattedDateSummary,
                isEnabled: isAssignmentEditable,
                showsChevron: false
            )
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.dateSummary)

            PeriodDatePicker(
                period: formModel.selectedPeriod,
                selectedDate: dateBinding,
                calendar: journalManager.calendar,
                today: journalManager.today,
                minimumDate: configuration.minimumDate(for: .day),
                maximumDate: configuration.maximumDate,
                accessibilityIdentifiers: .init(
                    dayPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.datePicker,
                    yearPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.yearPicker,
                    monthPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.monthPicker,
                    monthYearPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.monthYearPicker
                )
            )
            .disabled(!isAssignmentEditable)
            .opacity(isAssignmentEditable ? 1 : 0.6)
        }
    }

    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Assignment History")

            ForEach(Array(task.assignments.enumerated()), id: \.element) { index, assignment in
                HStack {
                    StatusIcon(
                        configuration: StatusIconConfiguration(
                            entryType: .task,
                            taskStatus: assignment.status,
                            size: .caption
                        ),
                        color: assignment.status.statusIconColor
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.period.displayName)
                            .font(.subheadline)
                        Text(formatAssignmentDate(assignment))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(assignment.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.TaskDetailSheet.assignmentHistoryRow(index)
                )
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.assignmentHistory)
    }

    private func lifecycleSection(
        title: String,
        icon: String,
        role: ButtonRole?,
        resultStatus: DataModel.Task.Status
    ) -> some View {
        Button(role: role) {
            selectedStatus = resultStatus
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
        }
        .accessibilityIdentifier(
            resultStatus == .cancelled
                ? Definitions.AccessibilityIdentifiers.TaskDetailSheet.cancelTaskButton
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.restoreTaskButton
        )
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

    private var formattedDateSummary: String {
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.timeZone = journalManager.calendar.timeZone

        switch formModel.selectedPeriod {
        case .year:
            formatter.dateFormat = "yyyy"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .day, .multiday:
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        }

        return formatter.string(from: formModel.effectiveSelectedDate)
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

    private func selectionSummaryRow(
        title: String,
        value: String,
        isEnabled: Bool,
        showsChevron: Bool = true
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
        )
        .opacity(isEnabled ? 1 : 0.7)
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

    private func save() {
        isSaving = true

        Task { @MainActor in
            do {
                if formModel.title != task.title {
                    try await journalManager.updateTaskTitle(task, newTitle: formModel.title)
                }

                if selectedStatus != task.status {
                    try await journalManager.updateTaskStatus(task, newStatus: selectedStatus)
                }

                if formModel.sanitizedBody != task.body ||
                   formModel.priority != task.priority ||
                   formModel.effectiveDueDate != task.dueDate {
                    try await journalManager.updateTaskMetadata(
                        task,
                        body: formModel.sanitizedBody,
                        priority: formModel.priority,
                        dueDate: formModel.effectiveDueDate
                    )
                }

                if selectedStatus.allowsAssignmentEditingInTaskSheet {
                    if formModel.hasPreferredAssignment {
                        let effectiveDate = formModel.effectiveSelectedDate
                        if !task.hasPreferredAssignment ||
                           effectiveDate != task.date ||
                           formModel.selectedPeriod != task.period {
                            try await journalManager.updateTaskDateAndPeriod(
                                task,
                                newDate: effectiveDate,
                                newPeriod: formModel.selectedPeriod
                            )
                        }
                    } else if task.hasPreferredAssignment {
                        try await journalManager.clearTaskPreferredAssignment(
                            task,
                            fallbackDate: formModel.effectiveSelectedDate,
                            fallbackPeriod: formModel.selectedPeriod
                        )
                    }
                }

                dismiss()
            } catch {
                isSaving = false
            }
        }
    }

    private func deleteTask() {
        Task { @MainActor in
            try? await journalManager.deleteTask(task)
            onDelete()
            dismiss()
        }
    }
}

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
