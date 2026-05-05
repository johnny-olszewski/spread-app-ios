import SwiftUI

/// Modal sheet for editing an existing task.
///
/// The task edit flow keeps lifecycle state and assignment state distinct:
/// - Status changes are draft-only until save.
/// - `.migrated` remains assignment history, not a user-editable task status.
/// - Period/date changes are disabled while the draft task is complete or cancelled.
struct TaskDetailSheet: View {

    // MARK: - ViewModel

    @Observable @MainActor final class ViewModel {
        var presentedTemporalContext: PresentedTemporalContext
        var selectedStatus: DataModel.Task.Status
        var formModel: TaskEditorFormModel
        var isSaving = false
        var isShowingDeleteConfirmation = false
        var isShowingSpreadPicker = false

        init(task: DataModel.Task, journalManager: JournalManager) {
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context
            selectedStatus = task.status
            let configuration = TaskCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            formModel = TaskEditorFormModel(configuration: configuration, task: task)
        }
    }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    let task: DataModel.Task
    @Bindable var journalManager: JournalManager
    let onDelete: () -> Void

    @State private var viewModel: ViewModel

    // MARK: - Computed Properties

    private var assignmentBinding: Binding<Bool> {
        Binding(
            get: { viewModel.formModel.hasPreferredAssignment },
            set: { viewModel.formModel.setPreferredAssignmentEnabled($0) }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.formModel.dueDate },
            set: { viewModel.formModel.dueDate = $0.startOfDay(calendar: viewModel.presentedTemporalContext.calendar) }
        )
    }

    private var configuration: TaskCreationConfiguration {
        viewModel.formModel.configuration
    }

    private var isAssignmentEditable: Bool {
        viewModel.selectedStatus.allowsAssignmentEditingInTaskSheet
    }

    init(
        task: DataModel.Task,
        journalManager: JournalManager,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self.journalManager = journalManager
        self.onDelete = onDelete
        _viewModel = State(initialValue: ViewModel(task: task, journalManager: journalManager))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
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

                    if let lifecycleActionTitle = viewModel.selectedStatus.lifecycleActionTitleInTaskSheet,
                       let lifecycleResult = viewModel.selectedStatus.lifecycleActionResultInTaskSheet,
                       let lifecycleIcon = viewModel.selectedStatus.lifecycleActionIconInTaskSheet {
                        compactDivider
                        lifecycleSection(
                            title: lifecycleActionTitle,
                            icon: lifecycleIcon,
                            role: viewModel.selectedStatus.lifecycleActionRoleInTaskSheet,
                            resultStatus: lifecycleResult
                        )
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
                    focusDate: viewModel.formModel.effectiveSelectedDate,
                    onSpreadSelected: { selection in
                        viewModel.formModel.applySpreadSelection(selection)
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
                    .disabled(
                        viewModel.isSaving ||
                        viewModel.formModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (
                            viewModel.formModel.hasPreferredAssignment &&
                            viewModel.formModel.selectedPeriod == .multiday &&
                            viewModel.formModel.selectedSpreadID == nil
                        )
                    )
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton)
                }
            }
            .alert("Delete Task", isPresented: $viewModel.isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
        }
        .localhostTemporalHarness(
            presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics(
                calendarIdentifier: viewModel.presentedTemporalContext.calendar.identifier,
                today: viewModel.presentedTemporalContext.today
            )
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Title")
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                TaskStatusToggleButton(
                    status: $viewModel.selectedStatus,
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusToggle
                )

                TextField("Task title", text: $viewModel.formModel.title)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.titleField)
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Metadata")

            Picker("Priority", selection: $viewModel.formModel.priority) {
                ForEach(DataModel.Task.Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.priorityPicker)

            Toggle("Due date", isOn: $viewModel.formModel.hasDueDate)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDateToggle)

            if viewModel.formModel.hasDueDate {
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
        DisclosureGroup("Details", isExpanded: $viewModel.formModel.isDetailsExpanded) {
            TextEditor(text: $viewModel.formModel.body)
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

            if viewModel.formModel.hasPreferredAssignment {
                spreadSelectionSection
                periodSection
                dateSection
            } else {
                Text(viewModel.formModel.periodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(isAssignmentEditable ? 1 : 0.7)
            }
        }
    }

    private var spreadSelectionSection: some View {
        Button {
            viewModel.isShowingSpreadPicker = true
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
                        viewModel.formModel.setPeriod(period)
                    } label: {
                        if period == viewModel.formModel.selectedPeriod {
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
                    value: viewModel.formModel.selectedPeriod.displayName,
                    isEnabled: isAssignmentEditable
                )
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodPicker)
            .disabled(!isAssignmentEditable)

            Text(viewModel.formModel.periodDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(isAssignmentEditable ? 1 : 0.7)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Date")

            selectionSummaryRow(
                title: viewModel.formModel.selectedPeriod == .multiday ? "Multiday spread" : "Date",
                value: formattedDateSummary,
                isEnabled: isAssignmentEditable,
                showsChevron: false
            )
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.dateSummary)

            if viewModel.formModel.selectedPeriod != .multiday {
                PeriodDatePicker(
                    period: viewModel.formModel.selectedPeriod,
                    selectedDate: $viewModel.formModel.selectedDate,
                    calendar: viewModel.presentedTemporalContext.calendar,
                    today: viewModel.presentedTemporalContext.today,
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
            viewModel.selectedStatus = resultStatus
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
            viewModel.isShowingDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Task")
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.deleteButton)
    }

    private var formattedDateSummary: String {
        if viewModel.formModel.selectedPeriod == .multiday {
            return selectedMultidaySummary
        }

        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.timeZone = journalManager.calendar.timeZone

        switch viewModel.formModel.selectedPeriod {
        case .year:
            formatter.dateFormat = "yyyy"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .day, .multiday:
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        }

        return formatter.string(from: viewModel.formModel.effectiveSelectedDate)
    }

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

    private var currentMultidaySpreadID: UUID? {
        task.assignments.first(where: { $0.status != .migrated && $0.period == .multiday })?.spreadID
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
        viewModel.isSaving = true

        Task { @MainActor in
            do {
                if viewModel.formModel.title != task.title {
                    try await journalManager.updateTaskTitle(task, newTitle: viewModel.formModel.title)
                }

                if viewModel.selectedStatus != task.status {
                    try await journalManager.updateTaskStatus(task, newStatus: viewModel.selectedStatus)
                }

                if viewModel.formModel.sanitizedBody != task.body ||
                   viewModel.formModel.priority != task.priority ||
                   viewModel.formModel.effectiveDueDate != task.dueDate {
                    try await journalManager.updateTaskMetadata(
                        task,
                        body: viewModel.formModel.sanitizedBody,
                        priority: viewModel.formModel.priority,
                        dueDate: viewModel.formModel.effectiveDueDate
                    )
                }

                if viewModel.selectedStatus.allowsAssignmentEditingInTaskSheet {
                    if viewModel.formModel.hasPreferredAssignment {
                        let effectiveDate = viewModel.formModel.effectiveSelectedDate
                        if !task.hasPreferredAssignment ||
                           effectiveDate != task.date ||
                           viewModel.formModel.selectedPeriod != task.period ||
                           viewModel.formModel.selectedSpreadID != currentMultidaySpreadID {
                            try await journalManager.updateTaskDateAndPeriod(
                                task,
                                newDate: effectiveDate,
                                newPeriod: viewModel.formModel.selectedPeriod,
                                preferredSpreadID: viewModel.formModel.selectedSpreadID
                            )
                        }
                    } else if task.hasPreferredAssignment {
                        try await journalManager.clearTaskPreferredAssignment(
                            task,
                            fallbackDate: viewModel.formModel.effectiveSelectedDate,
                            fallbackPeriod: viewModel.formModel.selectedPeriod
                        )
                    }
                }

                dismiss()
            } catch {
                viewModel.isSaving = false
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
