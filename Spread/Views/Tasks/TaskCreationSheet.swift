import SwiftUI

/// Modal sheet for creating a new task.
///
/// Supports task creation with:
/// - Title input (required, auto-focused)
/// - Period selection (year/month/day only)
/// - Period-appropriate date picker
/// - Inline validation with Create button visibility rules
struct TaskCreationSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    /// The journal manager for task creation.
    @Bindable var journalManager: JournalManager

    /// The currently selected spread, used for defaults.
    let selectedSpread: DataModel.Spread?

    /// Callback when a task is created.
    let onTaskCreated: (DataModel.Task) -> Void

    // MARK: - State

    @State private var presentedTemporalContext: PresentedTemporalContext
    @State private var formModel: TaskEditorFormModel
    @State private var isCreating = false
    @State private var isShowingSpreadPicker = false
    @FocusState private var isTitleFocused: Bool

    init(
        journalManager: JournalManager,
        selectedSpread: DataModel.Spread?,
        onTaskCreated: @escaping (DataModel.Task) -> Void
    ) {
        self.journalManager = journalManager
        self.selectedSpread = selectedSpread
        self.onTaskCreated = onTaskCreated
        let presentedTemporalContext = PresentedTemporalContext(journalManager: journalManager)
        _presentedTemporalContext = State(initialValue: presentedTemporalContext)
        let configuration = TaskCreationConfiguration(
            calendar: presentedTemporalContext.calendar,
            today: presentedTemporalContext.today
        )
        _formModel = State(
            initialValue: TaskEditorFormModel(
                configuration: configuration,
                selectedSpread: selectedSpread
            )
        )
    }

    // MARK: - Computed Properties

    private var configuration: TaskCreationConfiguration {
        formModel.configuration
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { formModel.title },
            set: { formModel.title = $0 }
        )
    }

    private var periodBinding: Binding<Period> {
        Binding(
            get: { formModel.selectedPeriod },
            set: { formModel.setPeriod($0) }
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
            set: { formModel.dueDate = $0.startOfDay(calendar: presentedTemporalContext.calendar) }
        )
    }

    /// Whether the Create button should be visible.
    ///
    /// Hidden until title is edited once; then always visible.
    private var isCreateButtonVisible: Bool {
        formModel.isCreateButtonVisible
    }

    /// Whether the form has any validation errors.
    private var hasValidationErrors: Bool {
        !configuration.validateTitle(formModel.title).isValid ||
        (
            formModel.hasPreferredAssignment &&
            !configuration.validateDate(
                period: formModel.selectedPeriod,
                date: formModel.effectiveSelectedDate
            ).isValid
        )
    }

    // MARK: - Body

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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .sheet(isPresented: $isShowingSpreadPicker) {
                SpreadPickerView(
                    spreads: journalManager.spreads,
                    calendar: presentedTemporalContext.calendar,
                    today: presentedTemporalContext.today,
                    focusDate: formModel.effectiveSelectedDate,
                    onSpreadSelected: { selection in
                        formModel.applySpreadSelection(selection)
                    },
                    onChooseCustomDate: {}
                )
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreateButtonVisible {
                        Button("Create") {
                            attemptCreate()
                        }
                        .disabled(isCreating)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.createButton)
                    }
                }
            }
            .onAppear {
                isTitleFocused = true
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
            TextField("Task title", text: titleBinding)
                .focused($isTitleFocused)
                .onChange(of: formModel.title) { _, _ in
                    formModel.handleTitleChange()
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField)

            if formModel.showValidationErrors, let error = formModel.titleError {
                validationErrorRow(message: error.message)
            }
        }
    }

    private var spreadSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Spread")
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
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.spreadPickerButton)
        }
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
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.priorityPicker)

            Toggle("Due date", isOn: dueDateEnabledBinding)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDateToggle)

            if formModel.hasDueDate {
                DatePicker(
                    "Due",
                    selection: dueDateBinding,
                    displayedComponents: .date
                )
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDatePicker)
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
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.bodyField)
        }
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Assign to spread", isOn: assignmentBinding)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.assignmentToggle)

            if formModel.hasPreferredAssignment {
                spreadSelectionSection
                periodSection
                dateSection
            } else {
                Text(formModel.periodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Period")
            TaskPeriodControl(
                selection: periodBinding,
                pickerIdentifier: Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodPicker,
                segmentIdentifier: {
                    Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodSegment($0.rawValue)
                }
            )

            Text(formModel.periodDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Date")
            if formModel.selectedPeriod == .multiday {
                Text(selectedMultidaySummary)
                    .font(.subheadline)
                    .foregroundStyle(formModel.selectedSpreadID == nil ? .secondary : .primary)
            } else {
                PeriodDatePicker(
                    period: formModel.selectedPeriod,
                    selectedDate: dateBinding,
                    calendar: presentedTemporalContext.calendar,
                    today: presentedTemporalContext.today,
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

            if formModel.showValidationErrors, let error = formModel.dateError {
                validationErrorRow(message: error.message)
            }
        }
    }

    private func validationErrorRow(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private var selectedMultidaySummary: String {
        guard let spreadID = formModel.selectedSpreadID,
              let spread = journalManager.spreads.first(where: { $0.id == spreadID }) else {
            return "Select an existing multiday spread above"
        }

        return SpreadPickerConfiguration(
            spreads: journalManager.spreads,
            calendar: presentedTemporalContext.calendar,
            today: presentedTemporalContext.today
        )
        .displayLabel(for: spread)
    }

    // MARK: - Actions

    private func attemptCreate() {
        guard formModel.validateForSubmission() else {
            return
        }

        createTask()
    }

    private func createTask() {
        isCreating = true

        Task {
            do {
                let task = try await journalManager.addTask(
                    title: formModel.title,
                    date: formModel.effectiveSelectedDate,
                    period: formModel.selectedPeriod,
                    preferredSpreadID: formModel.selectedSpreadID,
                    hasPreferredAssignment: formModel.hasPreferredAssignment,
                    body: formModel.sanitizedBody,
                    priority: formModel.priority,
                    dueDate: formModel.effectiveDueDate
                )
                await MainActor.run {
                    onTaskCreated(task)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    // Show error (could add alert here)
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Create Task") {
    TaskCreationSheet(
        journalManager: .previewInstance,
        selectedSpread: nil,
        onTaskCreated: { task in
            print("Created task: \(task.title)")
        }
    )
}

#Preview("With Selected Spread") {
    let calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }()

    let spread = DataModel.Spread(period: .month, date: Date(), calendar: calendar)

    return TaskCreationSheet(
        journalManager: .previewInstance,
        selectedSpread: spread,
        onTaskCreated: { task in
            print("Created task: \(task.title)")
        }
    )
}
