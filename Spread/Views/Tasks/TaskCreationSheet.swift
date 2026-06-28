import SwiftUI

/// Modal sheet for creating a new task.
///
/// Supports task creation with:
/// - Title input (required, auto-focused)
/// - Period selection (year/month/day only)
/// - Period-appropriate date picker
/// - Inline validation with Create button visibility rules
struct TaskCreationSheet: View {

    // MARK: - ViewModel

    @Observable @MainActor final class ViewModel {
        var presentedTemporalContext: PresentedTemporalContext
        var formModel: TaskEditorFormModel
        var isCreating = false
        var isShowingSpreadPicker = false

        init(journalManager: JournalManager, selectedSpread: DataModel.Spread?) {
            let context = PresentedTemporalContext(journalManager: journalManager)
            presentedTemporalContext = context
            let configuration = TaskCreationConfiguration(
                calendar: context.calendar,
                today: context.today
            )
            formModel = TaskEditorFormModel(configuration: configuration, selectedSpread: selectedSpread)
        }
    }

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

    @State private var viewModel: ViewModel
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    init(
        journalManager: JournalManager,
        selectedSpread: DataModel.Spread?,
        onTaskCreated: @escaping (DataModel.Task) -> Void
    ) {
        self.journalManager = journalManager
        self.selectedSpread = selectedSpread
        self.onTaskCreated = onTaskCreated
        _viewModel = State(initialValue: ViewModel(journalManager: journalManager, selectedSpread: selectedSpread))
    }

    // MARK: - Computed Properties

    private var configuration: TaskCreationConfiguration {
        viewModel.formModel.configuration
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

    /// Whether the Create button should be visible.
    ///
    /// Hidden until title is edited once; then always visible.
    private var isCreateButtonVisible: Bool {
        viewModel.formModel.isCreateButtonVisible
    }

    // MARK: - Body

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
                        .disabled(viewModel.isCreating)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.createButton)
                    }
                }
            }
            .onAppear {
                isTitleFocused = true
            }
        }
        .overlay {
            if viewModel.isCreating {
                loadingOverlay
            }
        }
        .interactiveDismissDisabled(isCreateButtonVisible)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
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
            TextField("Task title", text: $viewModel.formModel.title)
                .focused($isTitleFocused)
                .onChange(of: viewModel.formModel.title) { _, _ in
                    viewModel.formModel.handleTitleChange()
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField)

            if viewModel.formModel.showValidationErrors, let error = viewModel.formModel.titleError {
                validationErrorRow(message: error.message)
            }
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
                        Text("Select from existing spreads")
                        Text("Or choose a custom date below")
                            .font(SpreadTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(SpreadTheme.Typography.caption)
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

            Picker("Priority", selection: $viewModel.formModel.priority) {
                ForEach(DataModel.Task.Priority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.priorityPicker)

            Toggle("Due date", isOn: $viewModel.formModel.hasDueDate)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.dueDateToggle)

            if viewModel.formModel.hasDueDate {
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
        DisclosureGroup("Details", isExpanded: $viewModel.formModel.isDetailsExpanded) {
            TextEditor(text: $viewModel.formModel.body)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .background(SpreadTheme.Paper.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.bodyField)
        }
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Assign to spread", isOn: assignmentBinding)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.assignmentToggle)

            if viewModel.formModel.hasPreferredAssignment {
                spreadSelectionSection
                periodSection
                dateSection
            } else {
                Text(viewModel.formModel.periodDescription)
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Period")
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

            Text(viewModel.formModel.periodDescription)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Date")
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
                validationErrorRow(message: error.message)
            }
        }
    }

    private func validationErrorRow(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            SpreadTheme.Overlay.dim
            ProgressView()
        }
        .ignoresSafeArea()
    }

    private var compactDivider: some View {
        Divider()
            .padding(.vertical, 2)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.secondary)
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

    // MARK: - Actions

    private func attemptCreate() {
        guard viewModel.formModel.validateForSubmission() else {
            return
        }

        createTask()
    }

    private func createTask() {
        viewModel.isCreating = true

        Task {
            do {
                let task = try await journalManager.addTask(
                    title: viewModel.formModel.title,
                    date: viewModel.formModel.effectiveDate,
                    period: viewModel.formModel.effectivePeriod,
                    preferredSpreadID: viewModel.formModel.selectedSpreadID,
                    body: viewModel.formModel.sanitizedBody,
                    priority: viewModel.formModel.priority,
                    dueDate: viewModel.formModel.effectiveDueDate
                )
                await MainActor.run {
                    onTaskCreated(task)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    viewModel.isCreating = false
                    errorMessage = error.localizedDescription
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
        onTaskCreated: { _ in }
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
        onTaskCreated: { _ in }
    )
}
