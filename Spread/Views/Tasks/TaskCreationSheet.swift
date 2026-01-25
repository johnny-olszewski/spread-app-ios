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

    @State private var title: String = ""
    @State private var selectedPeriod: Period = .day
    @State private var selectedDate: Date = Date()
    @State private var hasEditedTitle = false
    @State private var showValidationErrors = false
    @State private var isCreating = false
    @State private var titleError: TaskCreationError?
    @State private var dateError: TaskCreationError?
    @FocusState private var isTitleFocused: Bool

    // MARK: - Computed Properties

    private var configuration: TaskCreationConfiguration {
        TaskCreationConfiguration(
            calendar: journalManager.calendar,
            today: journalManager.today
        )
    }

    /// Whether the Create button should be visible.
    ///
    /// Hidden until title is edited once; then always visible.
    private var isCreateButtonVisible: Bool {
        hasEditedTitle
    }

    /// Whether the form has any validation errors.
    private var hasValidationErrors: Bool {
        let result = configuration.validate(
            title: title,
            period: selectedPeriod,
            date: selectedDate
        )
        return !result.isValid
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                periodSection
                dateSection
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
                initializeDefaults()
                isTitleFocused = true
            }
            .onChange(of: selectedPeriod) { _, newPeriod in
                adjustDateForPeriod(newPeriod)
                clearDateError()
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            TextField("Task title", text: $title)
                .focused($isTitleFocused)
                .onChange(of: title) { _, _ in
                    if !hasEditedTitle {
                        hasEditedTitle = true
                    }
                    clearTitleError()
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField)

            if showValidationErrors, let error = titleError {
                validationErrorRow(message: error.message)
            }
        } header: {
            Text("Title")
        }
    }

    private var periodSection: some View {
        Section {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TaskCreationConfiguration.assignablePeriods, id: \.self) { period in
                    Text(period.displayName)
                        .tag(period)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodSegment(
                                period.rawValue
                            )
                        )
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodPicker)

            Text(periodDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Period")
        }
    }

    private var dateSection: some View {
        Section {
            datePicker

            if showValidationErrors, let error = dateError {
                validationErrorRow(message: error.message)
            }
        } header: {
            Text("Date")
        }
    }

    @ViewBuilder
    private var datePicker: some View {
        switch selectedPeriod {
        case .year:
            yearPicker
        case .month:
            monthPicker
        case .day:
            dayPicker
        case .multiday:
            // Multiday is not selectable for tasks, but handle gracefully
            dayPicker
        }
    }

    private var yearPicker: some View {
        Picker("Year", selection: $selectedDate) {
            ForEach(availableYears, id: \.self) { year in
                Text(String(year))
                    .tag(dateFor(year: year))
            }
        }
        .pickerStyle(.wheel)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.yearPicker)
    }

    private var monthPicker: some View {
        VStack(spacing: 12) {
            // Year picker
            Picker("Year", selection: Binding(
                get: { journalManager.calendar.component(.year, from: selectedDate) },
                set: { updateMonth(year: $0) }
            )) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year))
                        .tag(year)
                }
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.monthYearPicker)

            // Month picker
            Picker("Month", selection: Binding(
                get: { journalManager.calendar.component(.month, from: selectedDate) },
                set: { updateMonth(month: $0) }
            )) {
                ForEach(availableMonths, id: \.self) { month in
                    Text(monthName(for: month))
                        .tag(month)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.monthPicker)
        }
    }

    private var dayPicker: some View {
        DatePicker(
            "Date",
            selection: $selectedDate,
            in: configuration.minimumDate(for: .day)...configuration.maximumDate,
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.TaskCreationSheet.datePicker)
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

    // MARK: - Period Description

    private var periodDescription: String {
        switch selectedPeriod {
        case .year:
            return "Task will be assigned to a year spread"
        case .month:
            return "Task will be assigned to a month spread"
        case .day:
            return "Task will be assigned to a day spread"
        case .multiday:
            return "Task will be assigned to a day spread"
        }
    }

    // MARK: - Date Helpers

    private var availableYears: [Int] {
        let currentYear = journalManager.calendar.component(.year, from: journalManager.today)
        return Array(currentYear...(currentYear + 10))
    }

    private var availableMonths: [Int] {
        let currentYear = journalManager.calendar.component(.year, from: journalManager.today)
        let selectedYear = journalManager.calendar.component(.year, from: selectedDate)
        let currentMonth = journalManager.calendar.component(.month, from: journalManager.today)

        // If current year, only show current month and future
        if selectedYear == currentYear {
            return Array(currentMonth...12)
        }

        // Future years: all months
        return Array(1...12)
    }

    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        return formatter.monthSymbols[month - 1]
    }

    private func dateFor(year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        return journalManager.calendar.date(from: components) ?? journalManager.today
    }

    private func updateMonth(year: Int) {
        var components = journalManager.calendar.dateComponents([.month], from: selectedDate)
        components.year = year
        components.day = 1

        // Ensure month is valid for the new year
        let currentYear = journalManager.calendar.component(.year, from: journalManager.today)
        let currentMonth = journalManager.calendar.component(.month, from: journalManager.today)

        if year == currentYear, let month = components.month, month < currentMonth {
            components.month = currentMonth
        }

        if let newDate = journalManager.calendar.date(from: components) {
            selectedDate = newDate
        }
    }

    private func updateMonth(month: Int) {
        var components = journalManager.calendar.dateComponents([.year], from: selectedDate)
        components.month = month
        components.day = 1

        if let newDate = journalManager.calendar.date(from: components) {
            selectedDate = newDate
        }
    }

    // MARK: - Actions

    private func initializeDefaults() {
        let defaults = configuration.defaultSelection(from: selectedSpread)
        selectedPeriod = defaults.period
        selectedDate = defaults.date

        // Ensure date is within valid range
        adjustDateForPeriod(selectedPeriod)
    }

    private func adjustDateForPeriod(_ period: Period) {
        let minDate = configuration.minimumDate(for: period)

        // Normalize selected date to period and check if valid
        let normalizedSelected = period.normalizeDate(selectedDate, calendar: journalManager.calendar)

        if normalizedSelected < minDate {
            selectedDate = minDate
        }
    }

    private func clearTitleError() {
        if showValidationErrors {
            titleError = nil
        }
    }

    private func clearDateError() {
        if showValidationErrors {
            dateError = nil
        }
    }

    private func attemptCreate() {
        // Validate
        let titleResult = configuration.validateTitle(title)
        let dateResult = configuration.validateDate(period: selectedPeriod, date: selectedDate)

        // Show validation errors if any
        if !titleResult.isValid || !dateResult.isValid {
            showValidationErrors = true
            titleError = titleResult.error
            dateError = dateResult.error
            return
        }

        // Create the task
        createTask()
    }

    private func createTask() {
        isCreating = true

        Task {
            do {
                let task = try await journalManager.addTask(
                    title: title,
                    date: selectedDate,
                    period: selectedPeriod
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
