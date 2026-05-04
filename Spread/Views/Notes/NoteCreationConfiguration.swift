import Foundation

/// Validation errors for note creation.
enum NoteCreationError: Equatable {
    /// The title is empty or whitespace-only.
    case emptyTitle

    /// The selected date is in the past.
    case pastDate

    /// Multiday assignment requires choosing an existing multiday spread.
    case missingMultidaySpread

    /// User-facing error message.
    var message: String {
        switch self {
        case .emptyTitle:
            return "Title is required"
        case .pastDate:
            return "You can only create notes for present or future dates"
        case .missingMultidaySpread:
            return "Select an existing multiday spread"
        }
    }
}

/// Result of note creation validation.
struct NoteCreationResult {
    /// Whether creation is allowed.
    let isValid: Bool

    /// The error if creation is not allowed.
    let error: NoteCreationError?

    /// Creates a valid result.
    static var valid: NoteCreationResult {
        NoteCreationResult(isValid: true, error: nil)
    }

    /// Creates an invalid result with the given error.
    static func invalid(_ error: NoteCreationError) -> NoteCreationResult {
        NoteCreationResult(isValid: false, error: error)
    }
}

/// Configuration and validation logic for note creation.
///
/// Encapsulates the business rules for creating notes, including:
/// - Title validation (non-empty, non-whitespace-only)
/// - Date validation (present/future only using period-normalized comparison)
struct NoteCreationConfiguration {

    // MARK: - Properties

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date (typically today).
    let today: Date

    // MARK: - Validation

    /// Validates note creation parameters.
    ///
    /// Validation rules:
    /// - Title must not be empty or whitespace-only
    /// - Date must be >= today using period-normalized comparison
    ///
    /// - Parameters:
    ///   - title: The note title.
    ///   - period: The selected period for the note.
    ///   - date: The selected date for the note.
    /// - Returns: A result indicating whether creation is valid.
    func validate(title: String, period: Period, date: Date) -> NoteCreationResult {
        if title.isEmpty || title.allSatisfy(\.isWhitespace) {
            return .invalid(.emptyTitle)
        }

        if !isDateValid(period: period, date: date) {
            return .invalid(.pastDate)
        }

        return .valid
    }

    /// Validates only the title portion.
    ///
    /// - Parameter title: The note title to validate.
    /// - Returns: A result indicating whether the title is valid.
    func validateTitle(_ title: String) -> NoteCreationResult {
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
    func validateDate(period: Period, date: Date) -> NoteCreationResult {
        if !isDateValid(period: period, date: date) {
            return .invalid(.pastDate)
        }
        return .valid
    }

    /// Checks if the date is valid for the given period.
    func isDateValid(period: Period, date: Date) -> Bool {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let normalizedToday = period.normalizeDate(today, calendar: calendar)
        return normalizedDate >= normalizedToday
    }

    // MARK: - Date Ranges

    /// Returns the minimum selectable date for a given period.
    func minimumDate(for period: Period) -> Date {
        period.normalizeDate(today, calendar: calendar)
    }

    /// Returns the maximum selectable date (10 years in the future).
    var maximumDate: Date {
        calendar.date(byAdding: .year, value: 10, to: today) ?? today
    }

    // MARK: - Default Selection

    /// Computes the default period and date for note creation.
    ///
    /// If a spread is selected, uses the spread's period/date.
    /// Otherwise defaults to day period with today's date.
    func defaultSelection(from selectedSpread: DataModel.Spread?) -> (period: Period, date: Date) {
        guard let spread = selectedSpread else {
            return (.day, today)
        }

        let period = spread.period
        let date = spread.period == .multiday ? (spread.startDate ?? spread.date) : spread.date

        return (period, date)
    }

    /// Returns the assignable periods.
    static var assignablePeriods: [Period] {
        [.year, .month, .multiday, .day]
    }
}
