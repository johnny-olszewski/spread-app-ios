import Foundation

struct TaskEditorFormModel {

    let configuration: EntryCreationConfiguration

    var title: String
    var body: String
    var priority: DataModel.Task.Priority
    var hasDueDate: Bool
    var dueDate: Date
    /// Whether the user has added a scheduled time (SPRD-299). Only meaningful — and only
    /// offered by the sheet — while the assignment selection is day-period; see
    /// `effectiveScheduledTime` for the gating.
    var hasScheduledTime: Bool
    /// The clock time picked for the scheduled time. Only its hour/minute components are
    /// persisted, recombined with the assigned day in `effectiveScheduledTime`.
    var scheduledTimeOfDay: Date
    var selectedList: DataModel.List?
    var selectedTagIDs: Set<UUID>
    var hasPreferredAssignment: Bool
    var selectedPeriod: Period
    var selectedDate: Date
    var selectedSpreadID: UUID?
    /// First tap of an in-progress multiday range selection (start-of-day).
    var pendingRangeStart: Date?
    /// A completed multiday range with no matching existing spread — saving creates the spread.
    var pendingMultidayRange: ClosedRange<Date>?
    var hasEditedTitle: Bool
    var showValidationErrors = false
    var titleError: EntryCreationError?
    var dateError: EntryCreationError?

    init(
        configuration: EntryCreationConfiguration,
        selectedSpread: DataModel.Spread?
    ) {
        self.configuration = configuration
        let defaults = configuration.defaultSelection(from: selectedSpread)
        self.title = ""
        self.body = ""
        self.priority = .none
        self.hasDueDate = false
        self.dueDate = configuration.today.startOfDay(calendar: configuration.calendar)
        self.hasScheduledTime = false
        self.scheduledTimeOfDay = configuration.today
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
        configuration: EntryCreationConfiguration,
        task: DataModel.Task
    ) {
        self.configuration = configuration
        self.title = task.title
        self.body = task.body ?? ""
        self.priority = task.priority
        self.hasDueDate = task.dueDate != nil
        self.dueDate = (task.dueDate ?? configuration.today).startOfDay(calendar: configuration.calendar)
        self.hasScheduledTime = task.scheduledTime != nil
        self.scheduledTimeOfDay = task.scheduledTime ?? configuration.today
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

    /// Whether the scheduled-time chip applies to the current assignment selection: a time
    /// is only meaningful on a specific day (SPRD-299).
    var isScheduledTimeAvailable: Bool {
        hasPreferredAssignment && selectedPeriod == .day
    }

    /// The instant to persist as the task's `scheduledTime`, or `nil` when no time is set
    /// or the assignment selection isn't day-period. Built from the assigned day plus the
    /// picked clock time in the current calendar/timezone — the SPRD-296 "set" rule.
    var effectiveScheduledTime: Date? {
        guard isScheduledTimeAvailable, hasScheduledTime else { return nil }
        let calendar = configuration.calendar
        let components = calendar.dateComponents([.hour, .minute], from: scheduledTimeOfDay)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: effectiveSelectedDate
        )
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
            clearPendingMultidayRange()
        }
        if newPeriod != .day {
            hasScheduledTime = false
        }
        clearDateError()
    }

    mutating func applySpreadSelection(_ selection: SpreadPickerSelection) {
        hasPreferredAssignment = true
        selectedDate = configuration.adjustedDate(selection.date, for: selection.period)
        selectedPeriod = selection.period
        selectedSpreadID = selection.spreadID
        if selection.period != .day {
            hasScheduledTime = false
        }
        clearPendingMultidayRange()
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
        hasScheduledTime = false
        clearPendingMultidayRange()
        clearDateError()
    }

    // MARK: - Multiday range selection

    /// Whether the multiday assignment has a valid target: an existing spread or a pending
    /// range that will create one on save.
    var hasMultidaySelection: Bool {
        selectedSpreadID != nil || pendingMultidayRange != nil
    }

    /// Handles a tap on the multiday assignment calendar.
    ///
    /// First tap on a date covered by an existing multiday spread selects that spread.
    /// First tap on an uncovered date starts a free range; the second tap completes it.
    /// A completed range exactly matching an existing spread selects that spread; otherwise
    /// it is stored as `pendingMultidayRange`, to be created on save (SPRD-294).
    mutating func handleMultidayDayTap(_ date: Date, spreads: [DataModel.Spread]) {
        let calendar = configuration.calendar
        let day = date.startOfDay(calendar: calendar)

        if let start = pendingRangeStart {
            pendingRangeStart = nil
            let range = min(start, day)...max(start, day)
            if let match = multidaySpread(exactlyMatching: range, in: spreads) {
                applySpreadSelection(SpreadPickerSelection(
                    period: .multiday,
                    date: match.startDate ?? match.date,
                    spreadID: match.id
                ))
            } else {
                pendingMultidayRange = range
                hasPreferredAssignment = true
                selectedPeriod = .multiday
                selectedDate = range.lowerBound
                selectedSpreadID = nil
                clearDateError()
            }
        } else if let covering = spreads.first(where: {
            $0.period == .multiday && $0.contains(date: day, calendar: calendar)
        }) {
            applySpreadSelection(SpreadPickerSelection(
                period: .multiday,
                date: covering.startDate ?? covering.date,
                spreadID: covering.id
            ))
        } else {
            pendingRangeStart = day
        }
    }

    mutating func clearPendingMultidayRange() {
        pendingRangeStart = nil
        pendingMultidayRange = nil
    }

    private func multidaySpread(
        exactlyMatching range: ClosedRange<Date>,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        let calendar = configuration.calendar
        return spreads.first { spread in
            spread.period == .multiday &&
            (spread.startDate ?? spread.date).startOfDay(calendar: calendar) == range.lowerBound &&
            (spread.endDate ?? spread.date).startOfDay(calendar: calendar) == range.upperBound
        }
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
        let dateResult: EntryCreationResult
        if !hasPreferredAssignment {
            dateResult = .valid
        } else if selectedPeriod == .multiday && !hasMultidaySelection {
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
