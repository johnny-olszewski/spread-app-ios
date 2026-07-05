import SwiftUI

/// Unified sheet for Task creation and editing, built on the generic `EntrySheet` shell.
///
/// Replaces `TaskCreationSheet` (create mode) and `TaskDetailSheet` (edit mode).
/// All Task-specific section content (title, metadata, details, assignment) lives here;
/// the chrome (toolbar, loading overlay, delete confirmation, history/lifecycle sections)
/// is delegated to `EntrySheet`.
struct TaskEntrySheet: View {

    // MARK: - ViewModel

    @Observable @MainActor final class ViewModel {
        let mode: EntrySheetMode
        var presentedTemporalContext: PresentedTemporalContext
        var formModel: TaskEditorFormModel
        var selectedStatus: EntryStatus
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
            formModel = TaskEditorFormModel(configuration: configuration, selectedSpread: selectedSpread)
            selectedStatus = .open
        }

        /// Edit-mode initializer.
        init(task: DataModel.Task, journalManager: JournalManager) {
            mode = .edit
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context
            let configuration = EntryCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            formModel = TaskEditorFormModel(configuration: configuration, task: task)
            selectedStatus = task.status
        }
    }

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    @Bindable var journalManager: JournalManager

    // MARK: - Mode-specific data

    /// The task being edited (edit mode only).
    private let task: DataModel.Task?
    /// Callback when a task is created (create mode only).
    private let onTaskCreated: ((DataModel.Task) -> Void)?
    /// Callback when the task is deleted (edit mode only).
    private let onDelete: (() -> Void)?

    // MARK: - State

    @State private var viewModel: ViewModel
    @State private var coordinator = TaskEntrySheetCoordinator()
    @FocusState private var isTitleFocused: Bool

    // MARK: - Inits

    /// Create-mode entry point.
    init(
        journalManager: JournalManager,
        selectedSpread: DataModel.Spread?,
        onTaskCreated: @escaping (DataModel.Task) -> Void
    ) {
        self.journalManager = journalManager
        self.task = nil
        self.onTaskCreated = onTaskCreated
        self.onDelete = nil
        _viewModel = State(initialValue: ViewModel(journalManager: journalManager, selectedSpread: selectedSpread))
    }

    /// Edit-mode entry point.
    init(
        task: DataModel.Task,
        journalManager: JournalManager,
        onDelete: @escaping () -> Void
    ) {
        self.journalManager = journalManager
        self.task = task
        self.onTaskCreated = nil
        self.onDelete = onDelete
        _viewModel = State(initialValue: ViewModel(task: task, journalManager: journalManager))
    }

    // MARK: - Computed Properties

    private var configuration: EntryCreationConfiguration {
        viewModel.formModel.configuration
    }

    private var isAssignmentEditable: Bool {
        viewModel.selectedStatus.allowsAssignmentEditingInTaskSheet
    }

    private var isSaveEnabled: Bool {
        !viewModel.formModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(viewModel.formModel.hasPreferredAssignment &&
          viewModel.formModel.selectedPeriod == .multiday &&
          !viewModel.formModel.hasMultidaySelection)
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.formModel.dueDate },
            set: { viewModel.formModel.dueDate = $0.startOfDay(calendar: viewModel.presentedTemporalContext.calendar) }
        )
    }

    private var currentMultidaySpreadID: UUID? {
        task?.currentAssignments.first(where: { $0.period == .multiday })?.spreadID
    }

    // MARK: - Body

    var body: some View {
        @Bindable var viewModel = viewModel
        EntrySheet(
            navigationTitle: viewModel.mode == .create ? "New Task" : "Edit Task",
            mode: viewModel.mode,
            isBusy: viewModel.isBusy,
            cancelIdentifier: viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.cancelButton
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.cancelButton,
            primaryIdentifier: viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.createButton
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton,
            onCancel: { dismiss() },
            onPrimary: { viewModel.mode == .create ? attemptCreate() : save() },
            isPrimaryVisible: viewModel.formModel.isCreateButtonVisible,
            isSaveEnabled: isSaveEnabled,
            historySection: historyAnyView,
            deleteAction: task != nil ? { deleteTask() } : nil,
            deleteAlertTitle: "Delete Task",
            deleteAlertMessage: "Are you sure you want to delete this task? This action cannot be undone.",
            deleteButtonIdentifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.deleteButton,
            errorMessage: Binding(
                get: { viewModel.errorMessage },
                set: { viewModel.errorMessage = $0 }
            )
        ) {
            titleSection
            if viewModel.mode == .edit {
                statusSection
            }
            EntrySheetDivider()
            prioritySection
            dueDateSection
            listSection
            tagsSection
            EntrySheetDivider()
            notesSection
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
        guard let task, (!task.migrationHistory.isEmpty || !task.currentAssignments.isEmpty) else {
            return nil
        }
        return AnyView(assignmentHistorySection)
    }

    // MARK: - Sections

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Title")

            if viewModel.mode == .edit {
                TextField("Task title", text: $viewModel.formModel.title)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.titleField)
            } else {
                TextField("Task title", text: $viewModel.formModel.title)
                    .focused($isTitleFocused)
                    .onChange(of: viewModel.formModel.title) { _, _ in
                        viewModel.formModel.handleTitleChange()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField)

                if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.titleError {
                    EntrySheetValidationErrorRow(message: error.message)
                }
            }
        }
    }

    /// Edit-mode status choice row replacing the lifecycle section (Open / Complete /
    /// Cancelled). Migrated is terminal: it renders as a non-selectable informational chip.
    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Status")

            if viewModel.selectedStatus == .migrated {
                SpreadButton("Migrated", icon: .arrowRight, style: .tonal, size: .small) {}
                    .disabled(true)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker)
            } else {
                EntrySheetChoiceRow(
                    options: EntryStatus.userEditableTaskStatuses.map { status in
                        .init(
                            value: status,
                            title: status.displayName,
                            icon: statusOptionIcon(for: status),
                            accessibilityIdentifier: statusOptionIdentifier(for: status)
                        )
                    },
                    selection: viewModel.selectedStatus,
                    onSelect: { viewModel.selectedStatus = $0 }
                )
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker)
            }
        }
    }

    private func statusOptionIcon(for status: EntryStatus) -> SpreadTheme.Icon {
        switch status {
        case .complete: .checkCircle
        case .cancelled: .xmarkCircle
        default: .circle
        }
    }

    /// The Cancelled and Open options keep the legacy lifecycle-button identifiers
    /// (cancel/restore) so existing UI tests keep addressing the same transitions.
    private func statusOptionIdentifier(for status: EntryStatus) -> String? {
        switch status {
        case .cancelled: Definitions.AccessibilityIdentifiers.TaskDetailSheet.cancelTaskButton
        case .open: Definitions.AccessibilityIdentifiers.TaskDetailSheet.restoreTaskButton
        default: nil
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Priority")

            EntrySheetChoiceRow(
                options: DataModel.Task.Priority.allCases.map { priority in
                    .init(
                        value: priority,
                        title: priority.displayName,
                        icon: priority.icon,
                        iconTint: priority.iconColor
                    )
                },
                selection: viewModel.formModel.priority,
                onSelect: { viewModel.formModel.priority = $0 }
            )
            .accessibilityIdentifier(viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.priorityPicker
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.priorityPicker
            )
        }
    }

    @ViewBuilder
    private var dueDateSection: some View {
        let toggleIdentifier = viewModel.mode == .create
            ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDateToggle
            : Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDateToggle
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Due date")

            EntrySheetOptionalFieldChip(
                addTitle: "Add due date",
                valueTitle: viewModel.formModel.hasDueDate ? formattedDueDate : nil,
                addAccessibilityIdentifier: toggleIdentifier,
                valueAccessibilityIdentifier: toggleIdentifier,
                onAdd: {
                    viewModel.formModel.hasDueDate = true
                    coordinator.isDueDateCalendarVisible = true
                },
                onRemove: {
                    viewModel.formModel.hasDueDate = false
                    coordinator.isDueDateCalendarVisible = false
                },
                onValueTapped: {
                    coordinator.isDueDateCalendarVisible.toggle()
                }
            )

            if viewModel.formModel.hasDueDate && coordinator.isDueDateCalendarVisible {
                PeriodDatePicker(
                    period: .day,
                    selectedDate: dueDateBinding,
                    calendar: viewModel.presentedTemporalContext.calendar,
                    today: viewModel.presentedTemporalContext.today,
                    minimumDate: dueDateCalendarMinimumDate,
                    maximumDate: configuration.maximumDate,
                    accessibilityIdentifiers: .init(
                        dayPicker: viewModel.mode == .create
                            ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDatePicker
                            : Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDatePicker
                    )
                )
            }
        }
    }

    /// Formatted due date shown on the value chip (e.g. "Jul 12, 2026").
    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.calendar = viewModel.presentedTemporalContext.calendar
        formatter.timeZone = viewModel.presentedTemporalContext.calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: viewModel.formModel.dueDate)
    }

    /// Due dates may be in the past (overdue), unlike assignment dates — allow a wide back-range.
    private var dueDateCalendarMinimumDate: Date {
        let context = viewModel.presentedTemporalContext
        return context.calendar.date(byAdding: .year, value: -5, to: context.today) ?? context.today
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Notes")

            TextEditor(text: $viewModel.formModel.body)
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
                .background(SpreadTheme.Paper.secondary)
                .clipShape(RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.standard, style: .continuous))
                .accessibilityIdentifier(viewModel.mode == .create
                    ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.bodyField
                    : Definitions.AccessibilityIdentifiers.TaskDetailSheet.bodyField
                )
        }
    }

    @ViewBuilder
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Assignment")

            EntrySheetChoiceRow(
                options: [
                    .init(value: false, title: "Inbox", icon: .tray),
                    .init(value: true, title: "On a spread", icon: .calendar)
                ],
                selection: viewModel.formModel.hasPreferredAssignment,
                onSelect: { viewModel.formModel.setPreferredAssignmentEnabled($0) }
            )
            .accessibilityIdentifier(viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.assignmentToggle
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.assignmentToggle
            )
            .disabled(!isAssignmentEditable)
            .opacity(isAssignmentEditable ? 1 : 0.7)

            Text(viewModel.formModel.periodDescription)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .opacity(isAssignmentEditable ? 1 : 0.7)

            if viewModel.formModel.hasPreferredAssignment {
                periodSection
                dateSection
            }
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
                            ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodSegment(period.rawValue)
                            : Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodSegment(period.rawValue)
                    )
                },
                selection: viewModel.formModel.selectedPeriod,
                onSelect: { viewModel.formModel.setPeriod($0) }
            )
            .accessibilityIdentifier(viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodPicker
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodPicker
            )
            .disabled(!isAssignmentEditable)
            .opacity(isAssignmentEditable ? 1 : 0.7)
        }
    }

    @ViewBuilder
    private var dateSection: some View {
        let isMultiday = viewModel.formModel.selectedPeriod == .multiday
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: isMultiday ? "Spread" : "Date")

            if viewModel.mode == .edit {
                Text(formattedDateSummary)
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(isMultiday && viewModel.formModel.selectedSpreadID == nil ? .secondary : .primary)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.dateSummary)
            } else if isMultiday {
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
                        dayPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.datePicker,
                        yearPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.yearPicker,
                        monthPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.monthPicker,
                        monthYearPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.monthYearPicker
                    )
                    : .init(
                        dayPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.datePicker,
                        yearPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.yearPicker,
                        monthPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.monthPicker,
                        monthYearPicker: Definitions.AccessibilityIdentifiers.TaskDetailSheet.monthYearPicker
                    ),
                spreadContext: .init(
                    spreads: journalManager.spreads,
                    selectedSpreadID: viewModel.formModel.selectedSpreadID,
                    pendingRangeStart: viewModel.formModel.pendingRangeStart,
                    pendingRange: viewModel.formModel.pendingMultidayRange,
                    onMultidayDayTapped: { date in
                        viewModel.formModel.handleMultidayDayTap(date, spreads: journalManager.spreads)
                    }
                )
            )
            .disabled(!isAssignmentEditable)
            .opacity(isAssignmentEditable ? 1 : 0.6)

            if viewModel.mode == .create,
               viewModel.formModel.showValidationErrors, let error = viewModel.formModel.dateError {
                EntrySheetValidationErrorRow(message: error.message)
            }
        }
    }

    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Assignment History")
            ForEach(Array((task!.migrationHistory + task!.currentAssignments).enumerated()), id: \.element) {
                index, assignment in
                HStack {
                    EntryStatusIcon(
                        baseShape: EntryType.task.statusIconBaseShape,
                        bseeShapeConfig: .init(color: assignment.status.iconColor, iconSize: SpreadTheme.IconSize.medium),
                        overlay: assignment.status.overlayShape,
                        overlayConfig: .init(color: assignment.status.iconColor, iconSize: SpreadTheme.IconSize.medium)
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.period.displayName)
                            .font(SpreadTheme.Typography.subheadline)
                        Text(formatAssignmentDate(assignment))
                            .font(SpreadTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(assignment.status.displayName)
                        .font(SpreadTheme.Typography.caption)
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

    // MARK: - Helpers

    private var selectedMultidaySummary: String {
        if let range = viewModel.formModel.pendingMultidayRange {
            return "New spread: \(formattedRange(range))"
        }
        if viewModel.formModel.pendingRangeStart != nil {
            return "Now tap an end date"
        }
        guard let spreadID = viewModel.formModel.selectedSpreadID,
              let spread = journalManager.spreads.first(where: { $0.id == spreadID }) else {
            return "Tap an existing spread, or tap a start date"
        }
        return SpreadPickerConfiguration(
            spreads: journalManager.spreads,
            calendar: viewModel.presentedTemporalContext.calendar,
            today: viewModel.presentedTemporalContext.today
        )
        .displayLabel(for: spread)
    }

    private func formattedRange(_ range: ClosedRange<Date>) -> String {
        let formatter = DateIntervalFormatter()
        formatter.calendar = viewModel.presentedTemporalContext.calendar
        formatter.timeZone = viewModel.presentedTemporalContext.calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: range.lowerBound, to: range.upperBound)
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
        Task { @MainActor in
            var createdSpread: DataModel.Spread?
            do {
                var preferredSpreadID = viewModel.formModel.selectedSpreadID
                if let spread = try await createPendingMultidaySpreadIfNeeded() {
                    createdSpread = spread
                    preferredSpreadID = spread.id
                }
                let newTask = try await journalManager.addTask(
                    title: viewModel.formModel.title,
                    date: viewModel.formModel.effectiveDate,
                    period: viewModel.formModel.effectivePeriod,
                    preferredSpreadID: preferredSpreadID,
                    body: viewModel.formModel.sanitizedBody,
                    priority: viewModel.formModel.priority,
                    dueDate: viewModel.formModel.effectiveDueDate
                )
                onTaskCreated?(newTask)
                dismiss()
            } catch {
                if let createdSpread {
                    try? await journalManager.deleteSpread(createdSpread)
                }
                viewModel.isBusy = false
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    /// Creates the multiday spread backing a pending free range, if one is staged.
    /// Returns nil when the assignment already targets an existing spread.
    private func createPendingMultidaySpreadIfNeeded() async throws -> DataModel.Spread? {
        guard viewModel.formModel.hasPreferredAssignment,
              viewModel.formModel.selectedPeriod == .multiday,
              viewModel.formModel.selectedSpreadID == nil,
              let range = viewModel.formModel.pendingMultidayRange else { return nil }
        return try await journalManager.addMultidaySpread(
            startDate: range.lowerBound,
            endDate: range.upperBound
        )
    }

    private func save() {
        guard let task else { return }
        viewModel.isBusy = true
        Task { @MainActor in
            var createdSpread: DataModel.Spread?
            do {
                if viewModel.formModel.title != task.title {
                    try await journalManager.updateTaskTitle(task, newTitle: viewModel.formModel.title)
                }
                if viewModel.selectedStatus != task.status {
                    try await journalManager.updateTaskStatus(task, newStatus: viewModel.selectedStatus)
                }
                let selectedTags = journalManager.tags.filter {
                    viewModel.formModel.selectedTagIDs.contains($0.id)
                }
                let metadataChanged =
                    viewModel.formModel.sanitizedBody != task.body ||
                    viewModel.formModel.priority != task.priority ||
                    viewModel.formModel.effectiveDueDate != task.dueDate ||
                    viewModel.formModel.selectedList?.id != task.list?.id ||
                    Set(selectedTags.map(\.id)) != Set(task.tags.map(\.id))
                if metadataChanged {
                    try await journalManager.updateTaskMetadata(
                        task,
                        body: viewModel.formModel.sanitizedBody,
                        priority: viewModel.formModel.priority,
                        dueDate: viewModel.formModel.effectiveDueDate,
                        list: viewModel.formModel.selectedList,
                        tags: selectedTags
                    )
                }
                if viewModel.selectedStatus.allowsAssignmentEditingInTaskSheet {
                    if viewModel.formModel.hasPreferredAssignment {
                        let effectiveDate = viewModel.formModel.effectiveSelectedDate
                        if task.date == nil ||
                           effectiveDate != task.date ||
                           viewModel.formModel.selectedPeriod != task.period ||
                           viewModel.formModel.selectedSpreadID != currentMultidaySpreadID ||
                           viewModel.formModel.pendingMultidayRange != nil {
                            var preferredSpreadID = viewModel.formModel.selectedSpreadID
                            if let spread = try await createPendingMultidaySpreadIfNeeded() {
                                createdSpread = spread
                                preferredSpreadID = spread.id
                            }
                            try await journalManager.updateTaskDateAndPeriod(
                                task,
                                newDate: effectiveDate,
                                newPeriod: viewModel.formModel.selectedPeriod,
                                preferredSpreadID: preferredSpreadID
                            )
                        }
                    } else if task.date != nil {
                        try await journalManager.clearTaskPreferredAssignment(task)
                    }
                }
                dismiss()
            } catch {
                if let createdSpread {
                    try? await journalManager.deleteSpread(createdSpread)
                }
                viewModel.isBusy = false
            }
        }
    }

    /// Creates a list from the chip cloud's inline creation field and selects it.
    private func createList(named name: String) {
        Task { @MainActor in
            if let list = try? await journalManager.createList(name: name) {
                viewModel.formModel.selectedList = list
            }
        }
    }

    /// Creates a tag from the chip cloud's inline creation field and selects it.
    private func createTag(named name: String) {
        guard viewModel.formModel.selectedTagIDs.count < 5 else { return }
        Task { @MainActor in
            if let tag = try? await journalManager.createTag(name: name) {
                viewModel.formModel.selectedTagIDs.insert(tag.id)
            }
        }
    }

    private func deleteTask() {
        guard let task else { return }
        Task { @MainActor in
            try? await journalManager.deleteTask(task)
            onDelete?()
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("Create Task") {
    TaskEntrySheet(
        journalManager: .previewInstance,
        selectedSpread: nil,
        onTaskCreated: { _ in }
    )
}

#Preview("Edit Task") {
    let task = DataModel.Task(
        title: "Review project timeline",
        status: .open,
        currentAssignments: [
            Assignment(period: .month, date: Date(), status: .open)
        ]
    )
    TaskEntrySheet(
        task: task,
        journalManager: .previewInstance,
        onDelete: {}
    )
}
