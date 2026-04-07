import Foundation

struct TaskEditorFormModel {

    let configuration: TaskCreationConfiguration

    var title: String
    var selectedPeriod: Period
    var selectedDate: Date
    var hasEditedTitle: Bool
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
        self.selectedPeriod = defaults.period
        self.selectedDate = configuration.adjustedDate(defaults.date, for: defaults.period)
        self.hasEditedTitle = false
    }

    init(
        configuration: TaskCreationConfiguration,
        task: DataModel.Task
    ) {
        self.configuration = configuration
        self.title = task.title
        self.selectedPeriod = task.period
        self.selectedDate = task.date
        self.hasEditedTitle = true
    }

    var periodDescription: String {
        switch selectedPeriod {
        case .year:
            return "Task will be assigned to a year spread"
        case .month:
            return "Task will be assigned to a month spread"
        case .day, .multiday:
            return "Task will be assigned to a day spread"
        }
    }

    var isCreateButtonVisible: Bool {
        hasEditedTitle
    }

    var effectiveSelectedDate: Date {
        configuration.adjustedDate(selectedDate, for: selectedPeriod)
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
        clearDateError()
    }

    mutating func applySpreadSelection(period: Period, date: Date) {
        selectedDate = configuration.adjustedDate(date, for: period)
        selectedPeriod = period
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
        let dateResult = configuration.validateDate(period: selectedPeriod, date: selectedDate)

        if !titleResult.isValid || !dateResult.isValid {
            showValidationErrors = true
            titleError = titleResult.error
            dateError = dateResult.error
            return false
        }

        return true
    }
}
