import struct Foundation.Calendar
import struct Foundation.Date

/// Validation errors for task creation.
enum TaskCreationError: Equatable {
    /// The title is empty or whitespace-only.
    case emptyTitle

    /// The selected date is in the past.
    case pastDate

    /// User-facing error message.
    var message: String {
        switch self {
        case .emptyTitle:
            return "Title is required"
        case .pastDate:
            return "You can only create tasks for present or future dates"
        }
    }
}

/// Result of task creation validation.
struct TaskCreationResult {
    /// Whether creation is allowed.
    let isValid: Bool

    /// The error if creation is not allowed.
    let error: TaskCreationError?

    /// Creates a valid result.
    static var valid: TaskCreationResult {
        TaskCreationResult(isValid: true, error: nil)
    }

    /// Creates an invalid result with the given error.
    static func invalid(_ error: TaskCreationError) -> TaskCreationResult {
        TaskCreationResult(isValid: false, error: error)
    }
}

/// Configuration and validation logic for task creation.
///
/// Encapsulates the business rules for creating tasks, including:
/// - Title validation (non-empty, non-whitespace-only)
/// - Date validation (present/future only using period-normalized comparison)
struct TaskCreationConfiguration {

    // MARK: - Properties

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date (typically today).
    let today: Date

    // MARK: - Validation

    /// Validates task creation parameters.
    ///
    /// Validation rules:
    /// - Title must not be empty or whitespace-only (no trimming applied)
    /// - Date must be >= today using period-normalized comparison
    ///
    /// - Parameters:
    ///   - title: The task title.
    ///   - period: The selected period for the task.
    ///   - date: The selected date for the task.
    /// - Returns: A result indicating whether creation is valid.
    func validate(title: String, period: Period, date: Date) -> TaskCreationResult {
        // Title validation: empty or whitespace-only is invalid
        if title.isEmpty || title.allSatisfy(\.isWhitespace) {
            return .invalid(.emptyTitle)
        }

        // Date validation: period-normalized date must be >= today
        if !isDateValid(period: period, date: date) {
            return .invalid(.pastDate)
        }

        return .valid
    }

    /// Validates only the title portion.
    ///
    /// - Parameter title: The task title to validate.
    /// - Returns: A result indicating whether the title is valid.
    func validateTitle(_ title: String) -> TaskCreationResult {
        if title.isEmpty || title.allSatisfy(\.isWhitespace) {
            return .invalid(.emptyTitle)
        }
        return .valid
    }

    /// Validates only the date portion.
    ///
    /// - Parameters:
    ///   - period: The selected period.
    ///   - date: The selected date.
    /// - Returns: A result indicating whether the date is valid.
    func validateDate(period: Period, date: Date) -> TaskCreationResult {
        if !isDateValid(period: period, date: date) {
            return .invalid(.pastDate)
        }
        return .valid
    }

    /// Checks if the date is valid for the given period.
    ///
    /// Uses period-normalized comparison: the normalized date must be >= today's normalized date.
    ///
    /// - Parameters:
    ///   - period: The period for normalization.
    ///   - date: The date to check.
    /// - Returns: True if the date is present or future.
    func isDateValid(period: Period, date: Date) -> Bool {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let normalizedToday = period.normalizeDate(today, calendar: calendar)
        return normalizedDate >= normalizedToday
    }

    // MARK: - Date Ranges

    /// Returns the minimum selectable date for a given period.
    ///
    /// This is the normalized start of the current period.
    /// - Parameter period: The period to calculate for.
    /// - Returns: The minimum selectable date.
    func minimumDate(for period: Period) -> Date {
        period.normalizeDate(today, calendar: calendar)
    }

    /// Returns the maximum selectable date (10 years in the future).
    var maximumDate: Date {
        calendar.date(byAdding: .year, value: 10, to: today) ?? today
    }

    // MARK: - Default Selection

    /// Computes the default period and date for task creation.
    ///
    /// If a spread is selected:
    /// - Use the spread's period (converted to day if multiday)
    /// - Use the spread's date
    ///
    /// If no spread is selected:
    /// - Use `.day` period
    /// - Use today's date
    ///
    /// - Parameters:
    ///   - selectedSpread: The currently selected spread, if any.
    /// - Returns: A tuple of the default period and date.
    func defaultSelection(from selectedSpread: DataModel.Spread?) -> (period: Period, date: Date) {
        guard let spread = selectedSpread else {
            return (.day, today)
        }

        // Multiday spreads can't have tasks assigned, default to day
        let period: Period = spread.period == .multiday ? .day : spread.period

        // For multiday, use the start date; otherwise use the spread's date
        let date = spread.period == .multiday ? (spread.startDate ?? today) : spread.date

        return (period, date)
    }

    /// Returns the assignable periods (excludes multiday).
    static var assignablePeriods: [Period] {
        [.year, .month, .day]
    }
}
