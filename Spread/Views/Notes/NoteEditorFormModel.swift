import Foundation

/// Form state for Note creation and editing flows.
///
/// Mirrors `TaskEditorFormModel` for the Note field set: title, content,
/// list/tags, and period/date/spread assignment. No priority, due-date,
/// or details-body fields — those are Task-only.
struct NoteEditorFormModel {

    let configuration: EntryCreationConfiguration

    var title: String
    var content: String
    var selectedList: DataModel.List?
    var selectedTagIDs: Set<UUID>
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

    // MARK: - Inits

    /// Creates a form model seeded from the currently-viewed spread.
    init(configuration: EntryCreationConfiguration, selectedSpread: DataModel.Spread?) {
        self.configuration = configuration
        let defaults = configuration.defaultSelection(from: selectedSpread)
        self.title = ""
        self.content = ""
        self.selectedList = nil
        self.selectedTagIDs = []
        self.selectedPeriod = defaults.period
        if defaults.period == .multiday {
            self.selectedDate = defaults.period.normalizeDate(defaults.date, calendar: configuration.calendar)
        } else {
            self.selectedDate = configuration.adjustedDate(defaults.date, for: defaults.period)
        }
        self.selectedSpreadID = selectedSpread?.period == .multiday ? selectedSpread?.id : nil
        self.hasEditedTitle = false
    }

    /// Creates a form model pre-populated from an existing note for editing.
    init(configuration: EntryCreationConfiguration, note: DataModel.Note) {
        self.configuration = configuration
        self.title = note.title
        self.content = note.content
        self.selectedList = note.list
        self.selectedTagIDs = Set(note.tags.map(\.id))
        self.selectedPeriod = note.period
        self.selectedDate = note.date ?? note.createdDate
        self.selectedSpreadID = note.currentAssignments.first(where: {
            $0.period == .multiday
        })?.spreadID
        self.hasEditedTitle = true
    }

    // MARK: - Computed Properties

    var periodDescription: String {
        switch selectedPeriod {
        case .year:   return "Note will be assigned to a year spread"
        case .month:  return "Note will be assigned to a month spread"
        case .multiday: return "Note will be assigned to an existing multiday spread"
        case .day:    return "Note will be assigned to a day spread"
        }
    }

    var isCreateButtonVisible: Bool {
        hasEditedTitle
    }

    /// The effective selected date, normalized and clamped to the minimum for the current period.
    var effectiveSelectedDate: Date {
        configuration.adjustedDate(selectedDate, for: selectedPeriod)
    }

    var sanitizedContent: String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Mutations

    mutating func handleTitleChange() {
        if !hasEditedTitle {
            hasEditedTitle = true
        }
        clearTitleError()
    }

    mutating func setPeriod(_ newPeriod: Period) {
        selectedDate = configuration.adjustedDate(selectedDate, for: newPeriod)
        selectedPeriod = newPeriod
        if newPeriod != .multiday {
            selectedSpreadID = nil
            clearPendingMultidayRange()
        }
        clearDateError()
    }

    mutating func applySpreadSelection(_ selection: SpreadPickerSelection) {
        selectedDate = configuration.adjustedDate(selection.date, for: selection.period)
        selectedPeriod = selection.period
        selectedSpreadID = selection.spreadID
        clearPendingMultidayRange()
        clearDateError()
    }

    // MARK: - Multiday range selection

    /// Whether the multiday assignment has a valid target: an existing spread or a pending
    /// range that will create one on save.
    var hasMultidaySelection: Bool {
        selectedSpreadID != nil || pendingMultidayRange != nil
    }

    /// Handles a tap on the multiday assignment calendar — same semantics as
    /// `TaskEditorFormModel.handleMultidayDayTap(_:spreads:)`.
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
        if selectedPeriod == .multiday && !hasMultidaySelection {
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
