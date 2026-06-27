import Foundation

struct TaskEditorFormModel {

    let configuration: TaskCreationConfiguration

    var title: String
    var body: String
    var priority: DataModel.Task.Priority
    var hasDueDate: Bool
    var dueDate: Date
    var selectedList: DataModel.List?
    var selectedTagIDs: Set<UUID>
    var hasPreferredAssignment: Bool
    var selectedPeriod: Period
    var selectedDate: Date
    var selectedSpreadID: UUID?
    var hasEditedTitle: Bool
    var isDetailsExpanded = false
    var showValidationErrors = false
    var titleError: TaskCreationError?
    var dateError: TaskCreationError?

    init(
        configuration: TaskCreationConfiguration,
        selectedSpread: DataModel.Spread?
    ) {
        self.configuration = configuration
        let defaults = configuration.defaultSelection(from: selectedSpread)
        self.title = ""
        self.body = ""
        self.priority = .none
        self.hasDueDate = false
        self.dueDate = configuration.today.startOfDay(calendar: configuration.calendar)
        self.selectedList = nil
        self.selectedTagIDs = []
        self.hasPreferredAssignment = selectedSpread != nil
        self.selectedPeriod = defaults.period
        if selectedSpread?.period == .multiday {
            self.selectedDate = defaults.date
        } else {
            self.selectedDate = configuration.adjustedDate(defaults.date, for: defaults.period)
        }
        self.selectedSpreadID = selectedSpread?.period == .multiday ? selectedSpread?.id : nil
        self.hasEditedTitle = false
    }

    init(
        configuration: TaskCreationConfiguration,
        task: DataModel.Task
    ) {
        self.configuration = configuration
        self.title = task.title
        self.body = task.body ?? ""
        self.priority = task.priority
        self.hasDueDate = task.dueDate != nil
        self.dueDate = (task.dueDate ?? configuration.today).startOfDay(calendar: configuration.calendar)
        self.selectedList = task.list
        self.selectedTagIDs = Set(task.tags.map(\.id))
        self.hasPreferredAssignment = task.date != nil
        self.selectedPeriod = task.date != nil ? (task.period ?? .day) : .day
        let today = configuration.today.startOfDay(calendar: configuration.calendar)
        self.selectedDate = task.date ?? today
        self.selectedSpreadID = task.currentAssignments.first(where: {
            $0.period == .multiday
        })?.spreadID
        self.hasEditedTitle = true
    }

    var periodDescription: String {
        guard hasPreferredAssignment else {
            return "Task will stay in Inbox until assigned"
        }

        switch selectedPeriod {
        case .year:
            return "Task will be assigned to a year spread"
        case .month:
            return "Task will be assigned to a month spread"
        case .multiday:
            return "Task will be assigned to an existing multiday spread"
        case .day:
            return "Task will be assigned to a day spread"
        }
    }

    var isCreateButtonVisible: Bool {
        hasEditedTitle
    }

    var effectiveSelectedDate: Date {
        configuration.adjustedDate(selectedDate, for: selectedPeriod)
    }

    /// The date to persist, or `nil` when the user has no preferred assignment.
    var effectiveDate: Date? {
        hasPreferredAssignment ? effectiveSelectedDate : nil
    }

    /// The period to persist, or `nil` when the user has no preferred assignment.
    var effectivePeriod: Period? {
        hasPreferredAssignment ? selectedPeriod : nil
    }

    var sanitizedBody: String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var effectiveDueDate: Date? {
        guard hasDueDate else { return nil }
        return dueDate.startOfDay(calendar: configuration.calendar)
    }

    mutating func handleTitleChange() {
        if !hasEditedTitle {
            hasEditedTitle = true
        }
        clearTitleError()
    }

    mutating func handlePeriodChange(_ newPeriod: Period) {
        setPeriod(newPeriod)
    }

    mutating func setPeriod(_ newPeriod: Period) {
        selectedDate = configuration.adjustedDate(selectedDate, for: newPeriod)
        selectedPeriod = newPeriod
        if newPeriod != .multiday {
            selectedSpreadID = nil
        }
        clearDateError()
    }

    mutating func applySpreadSelection(_ selection: SpreadPickerSelection) {
        hasPreferredAssignment = true
        selectedDate = configuration.adjustedDate(selection.date, for: selection.period)
        selectedPeriod = selection.period
        selectedSpreadID = selection.spreadID
        clearDateError()
    }

    mutating func setPreferredAssignmentEnabled(_ isEnabled: Bool) {
        guard hasPreferredAssignment != isEnabled else { return }
        hasPreferredAssignment = isEnabled
        if isEnabled {
            selectedPeriod = .day
            selectedDate = configuration.today.startOfDay(calendar: configuration.calendar)
            selectedSpreadID = nil
        }
        clearDateError()
    }

    mutating func clearTitleError() {
        if showValidationErrors {
            titleError = nil
        }
    }

    mutating func clearDateError() {
        if showValidationErrors {
            dateError = nil
        }
    }

    mutating func validateForSubmission() -> Bool {
        let titleResult = configuration.validateTitle(title)
        let dateResult: TaskCreationResult
        if !hasPreferredAssignment {
            dateResult = .valid
        } else if selectedPeriod == .multiday && selectedSpreadID == nil {
            dateResult = .invalid(.missingMultidaySpread)
        } else if selectedPeriod == .multiday {
            dateResult = .valid
        } else {
            dateResult = configuration.validateDate(period: selectedPeriod, date: selectedDate)
        }

        if !titleResult.isValid || !dateResult.isValid {
            showValidationErrors = true
            titleError = titleResult.error
            dateError = dateResult.error
            return false
        }

        return true
    }
}
