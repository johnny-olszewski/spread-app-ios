import Foundation

/// Configuration and validation logic shared across all entry creation and editing flows.
///
/// Encapsulates business rules for creating or editing tasks, notes, and other entries:
/// - Title validation (non-empty, non-whitespace-only)
/// - Date validation (present/future only, using period-normalized comparison)
/// - Date range bounds for picker UI
/// - Default period/date selection from a currently-viewed spread
struct EntryCreationConfiguration {

    // MARK: - Properties

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The reference date (typically today).
    let today: Date

    // MARK: - Validation

    /// Validates only the title portion.
    ///
    /// - Parameter title: The entry title to validate.
    /// - Returns: A result indicating whether the title is valid.
    func validateTitle(_ title: String) -> EntryCreationResult {
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
    func validateDate(period: Period, date: Date) -> EntryCreationResult {
        if !isDateValid(period: period, date: date) {
            return .invalid(.pastDate)
        }
        return .valid
    }

    /// Returns whether the date is valid for the given period.
    ///
    /// Uses period-normalized comparison: the normalized date must be >= today's normalized date.
    func isDateValid(period: Period, date: Date) -> Bool {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let normalizedToday = period.normalizeDate(today, calendar: calendar)
        return normalizedDate >= normalizedToday
    }

    // MARK: - Date Ranges

    /// Returns the minimum selectable date for a given period.
    ///
    /// This is the normalized start of the current period.
    func minimumDate(for period: Period) -> Date {
        period.normalizeDate(today, calendar: calendar)
    }

    /// Returns the adjusted selected date when the editor changes periods.
    ///
    /// Normalizes the date to the new period and clamps it to the minimum valid date,
    /// so create and edit flows resolve the same effective preferred assignment.
    func adjustedDate(_ date: Date, for period: Period) -> Date {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        if period == .multiday {
            return normalizedDate
        }
        let minimumDate = minimumDate(for: period)
        return normalizedDate < minimumDate ? minimumDate : normalizedDate
    }

    /// Returns the maximum selectable date (10 years in the future).
    var maximumDate: Date {
        calendar.date(byAdding: .year, value: 10, to: today) ?? today
    }

    // MARK: - Default Selection

    /// Computes the default period and date for entry creation given the currently-viewed spread.
    ///
    /// - For multiday spreads: uses `.day` period with `today` if today is in range,
    ///   otherwise the spread's start date.
    /// - For all other spread periods: uses the spread's own period and date.
    /// - For no spread: uses `.day` period and `today`.
    func defaultSelection(from selectedSpread: DataModel.Spread?) -> (period: Period, date: Date) {
        guard let spread = selectedSpread else {
            return (.day, today)
        }

        if spread.period == .multiday {
            let date = spread.contains(date: today, calendar: calendar)
                ? today
                : (spread.startDate ?? spread.date)
            return (.day, date)
        }

        return (spread.period, spread.date)
    }

    // MARK: - Assignable Periods

    /// The periods available for entry assignment.
    static var assignablePeriods: [Period] {
        [.year, .month, .multiday, .day]
    }
}
