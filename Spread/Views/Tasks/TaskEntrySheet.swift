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
          viewModel.formModel.selectedSpreadID == nil)
    }

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
            lifecycleSection: lifecycleAnyView,
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
            EntrySheetDivider()
            metadataSection
            EntrySheetDivider()
            detailsSection
            EntrySheetDivider()
            assignmentSection
        }
        .sheet(item: $coordinator.activeSheet) { destination in
            switch destination {
            case .spreadPicker:
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

    private var lifecycleAnyView: AnyView? {
        guard
            viewModel.mode == .edit,
            let title = viewModel.selectedStatus.lifecycleActionTitleInTaskSheet,
            let result = viewModel.selectedStatus.lifecycleActionResultInTaskSheet,
            let icon = viewModel.selectedStatus.lifecycleActionIconInTaskSheet
        else { return nil }
        return AnyView(lifecycleSection(
            title: title,
            icon: icon,
            role: viewModel.selectedStatus.lifecycleActionRoleInTaskSheet,
            resultStatus: result
        ))
    }

    // MARK: - Sections

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Title")

            if viewModel.mode == .edit {
                HStack(spacing: 8) {
                    Button {} label: {
                        EntryStatusIcon(
                            baseShape: EntryType.task.statusIconBaseShape,
                            bseeShapeConfig: .init(color: viewModel.selectedStatus.iconColor, iconSize: 24),
                            overlay: viewModel.selectedStatus.overlayShape,
                            overlayConfig: .init(color: viewModel.selectedStatus.iconColor, iconSize: 24)
                        )
                        .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(false)

                    TextField("Task title", text: $viewModel.formModel.title)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.titleField)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker)
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

    @ViewBuilder
    private var metadataSection: some View {
        @Bindable var coordinator = coordinator
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Metadata")

            Picker("Priority", selection: $viewModel.formModel.priority) {
                ForEach(DataModel.Task.Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(viewModel.mode == .create
                ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.priorityPicker
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.priorityPicker
            )

            Toggle("Due date", isOn: $viewModel.formModel.hasDueDate)
                .accessibilityIdentifier(viewModel.mode == .create
                    ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDateToggle
                    : Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDateToggle
                )

            if viewModel.formModel.hasDueDate {
                DatePicker("Due", selection: dueDateBinding, displayedComponents: .date)
                    .accessibilityIdentifier(viewModel.mode == .create
                        ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDatePicker
                        : Definitions.AccessibilityIdentifiers.TaskDetailSheet.dueDatePicker
                    )
            }

            listPickerRow
            tagsPickerSection
        }
        .alert("New List", isPresented: $coordinator.isCreatingList) {
            TextField("List name", text: $coordinator.newListName)
            Button("Create") { createList() }
            Button("Cancel", role: .cancel) { coordinator.newListName = "" }
        }
        .alert("New Tag", isPresented: $coordinator.isCreatingTag) {
            TextField("Tag name", text: $coordinator.newTagName)
            Button("Create") { createTag() }
            Button("Cancel", role: .cancel) { coordinator.newTagName = "" }
        }
    }

    @ViewBuilder
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
            Button("New List…") { coordinator.isCreatingList = true }
        } label: {
            EntrySheetSelectionSummaryRow(
                title: "List",
                value: viewModel.formModel.selectedList?.name ?? "None",
                isEnabled: true
            )
        }
    }

    @ViewBuilder
    private var tagsPickerSection: some View {
        @Bindable var coordinator = coordinator
        DisclosureGroup(isExpanded: $coordinator.isTagsExpanded) {
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
                Button("New Tag…") { coordinator.isCreatingTag = true }
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

    @ViewBuilder
    private var detailsSection: some View {
        DisclosureGroup("Details", isExpanded: $viewModel.formModel.isDetailsExpanded) {
            TextEditor(text: $viewModel.formModel.body)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .background(SpreadTheme.Paper.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier(viewModel.mode == .create
                    ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.bodyField
                    : Definitions.AccessibilityIdentifiers.TaskDetailSheet.bodyField
                )
        }
    }

    @ViewBuilder
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: viewModel.mode == .create ? "Assignment" : "Assignment")

            Toggle("Assign to spread", isOn: assignmentBinding)
                .disabled(!isAssignmentEditable)
                .opacity(isAssignmentEditable ? 1 : 0.7)
                .accessibilityIdentifier(viewModel.mode == .create
                    ? Definitions.AccessibilityIdentifiers.TaskCreationSheet.assignmentToggle
                    : Definitions.AccessibilityIdentifiers.TaskDetailSheet.assignmentToggle
                )

            if viewModel.formModel.hasPreferredAssignment {
                spreadSelectionSection
                periodSection
                dateSection
            } else {
                Text(viewModel.formModel.periodDescription)
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .opacity(isAssignmentEditable ? 1 : 0.7)
            }

            if viewModel.mode == .create && viewModel.formModel.hasPreferredAssignment {
                spreadPickerButton
            }
        }
    }

    @ViewBuilder
    private var spreadPickerButton: some View {
        Button {
            coordinator.showSpreadPicker()
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
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.spreadPickerButton)
    }

    @ViewBuilder
    private var spreadSelectionSection: some View {
        if viewModel.mode == .edit {
            Button {
                coordinator.showSpreadPicker()
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
            .disabled(!isAssignmentEditable)
            .opacity(isAssignmentEditable ? 1 : 0.7)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.spreadPickerButton)
        }
    }

    @ViewBuilder
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Period")

            if viewModel.mode == .create {
                TaskPeriodControl(
                    selection: Binding(
                        get: { viewModel.formModel.selectedPeriod },
                        set: { viewModel.formModel.setPeriod($0) }
                    ),
                    pickerIdentifier: Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodPicker,
                    segmentIdentifier: {
                        Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodSegment($0.rawValue)
                    }
                )
            } else {
                Menu {
                    ForEach(EntryCreationConfiguration.assignablePeriods, id: \.self) { period in
                        Button {
                            viewModel.formModel.setPeriod(period)
                        } label: {
                            if period == viewModel.formModel.selectedPeriod {
                                Label {
                                    Text(period.displayName)
                                } icon: {
                                    SpreadTheme.Icon.checkmark.sized(SpreadTheme.IconSize.small)
                                }
                            } else {
                                Text(period.displayName)
                            }
                        }
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodSegment(period.rawValue)
                        )
                    }
                } label: {
                    EntrySheetSelectionSummaryRow(
                        title: "Period",
                        value: viewModel.formModel.selectedPeriod.displayName,
                        isEnabled: isAssignmentEditable
                    )
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodPicker)
                .disabled(!isAssignmentEditable)
            }

            Text(viewModel.formModel.periodDescription)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .opacity(isAssignmentEditable ? 1 : 0.7)
        }
    }

    @ViewBuilder
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            EntrySheetSectionHeader(title: "Date")

            if viewModel.mode == .create {
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
                        minimumDate: configuration.minimumDate(for: .day),
                        maximumDate: configuration.maximumDate,
                        accessibilityIdentifiers: .init(
                            dayPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.datePicker,
                            yearPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.yearPicker,
                            monthPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.monthPicker,
                            monthYearPicker: Definitions.AccessibilityIdentifiers.TaskCreationSheet.monthYearPicker
                        )
                    )
                }

                if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.dateError {
                    EntrySheetValidationErrorRow(message: error.message)
                }
            } else {
                EntrySheetSelectionSummaryRow(
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

    private func lifecycleSection(
        title: String,
        icon: SpreadTheme.Icon,
        role: ButtonRole?,
        resultStatus: EntryStatus
    ) -> some View {
        Button(role: role) {
            viewModel.selectedStatus = resultStatus
        } label: {
            HStack {
                icon.sized(SpreadTheme.IconSize.medium)
                    .iconTint(role == .destructive ? .red : .accentColor)
                Text(title)
            }
        }
        .accessibilityIdentifier(
            resultStatus == .cancelled
                ? Definitions.AccessibilityIdentifiers.TaskDetailSheet.cancelTaskButton
                : Definitions.AccessibilityIdentifiers.TaskDetailSheet.restoreTaskButton
        )
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
        Task {
            do {
                let newTask = try await journalManager.addTask(
                    title: viewModel.formModel.title,
                    date: viewModel.formModel.effectiveDate,
                    period: viewModel.formModel.effectivePeriod,
                    preferredSpreadID: viewModel.formModel.selectedSpreadID,
                    body: viewModel.formModel.sanitizedBody,
                    priority: viewModel.formModel.priority,
                    dueDate: viewModel.formModel.effectiveDueDate
                )
                await MainActor.run {
                    onTaskCreated?(newTask)
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
        guard let task else { return }
        viewModel.isBusy = true
        Task { @MainActor in
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
                           viewModel.formModel.selectedSpreadID != currentMultidaySpreadID {
                            try await journalManager.updateTaskDateAndPeriod(
                                task,
                                newDate: effectiveDate,
                                newPeriod: viewModel.formModel.selectedPeriod,
                                preferredSpreadID: viewModel.formModel.selectedSpreadID
                            )
                        }
                    } else if task.date != nil {
                        try await journalManager.clearTaskPreferredAssignment(task)
                    }
                }
                dismiss()
            } catch {
                viewModel.isBusy = false
            }
        }
    }

    private func createList() {
        let name = coordinator.newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        coordinator.newListName = ""
        guard !name.isEmpty else { return }
        Task { @MainActor in
            if let list = try? await journalManager.createList(name: name) {
                viewModel.formModel.selectedList = list
            }
        }
    }

    private func createTag() {
        let name = coordinator.newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        coordinator.newTagName = ""
        guard !name.isEmpty, viewModel.formModel.selectedTagIDs.count < 5 else { return }
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
