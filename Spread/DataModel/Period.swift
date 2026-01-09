import struct Foundation.Calendar
import struct Foundation.Date

/// Time period for a spread.
///
/// Defines the granularity of a journaling page. Week period is explicitly
/// NOT supported per spec requirements (Non-Goals).
enum Period: String, CaseIterable, Codable {
    /// A full calendar year.
    case year

    /// A single calendar month.
    case month

    /// A single calendar day.
    case day

    /// A custom date range (used for week-like views).
    case multiday

    // MARK: - Display

    /// The display name for this period.
    var displayName: String {
        switch self {
        case .year:
            return "Year"
        case .month:
            return "Month"
        case .day:
            return "Day"
        case .multiday:
            return "Multiday"
        }
    }

    // MARK: - Calendar Integration

    /// The corresponding Calendar.Component for this period.
    ///
    /// Returns `nil` for multiday since it uses custom date ranges.
    var calendarComponent: Calendar.Component? {
        switch self {
        case .year:
            return .year
        case .month:
            return .month
        case .day:
            return .day
        case .multiday:
            return nil
        }
    }

    // MARK: - Assignment Rules

    /// Whether tasks and notes can be directly assigned to spreads of this period.
    ///
    /// Multiday spreads aggregate entries by date range rather than direct assignment.
    var canHaveTasksAssigned: Bool {
        switch self {
        case .year, .month, .day:
            return true
        case .multiday:
            return false
        }
    }

    // MARK: - Period Hierarchy

    /// The child period in the hierarchy (year → month → day).
    ///
    /// Used for navigation and grouping. Returns `nil` for day (leaf) and multiday.
    var childPeriod: Period? {
        switch self {
        case .year:
            return .month
        case .month:
            return .day
        case .day, .multiday:
            return nil
        }
    }

    /// The parent period in the hierarchy (day → month → year).
    ///
    /// Used for migration fallback and assignment resolution. Returns `nil` for year (root) and multiday.
    var parentPeriod: Period? {
        switch self {
        case .year, .multiday:
            return nil
        case .month:
            return .year
        case .day:
            return .month
        }
    }

    // MARK: - Date Normalization

    /// Normalizes a date to the start of this period.
    ///
    /// - Parameters:
    ///   - date: The date to normalize.
    ///   - calendar: The calendar to use for normalization.
    /// - Returns: The normalized date, or the original date if normalization fails.
    func normalizeDate(_ date: Date, calendar: Calendar) -> Date {
        switch self {
        case .year:
            return date.firstDayOfYear(calendar: calendar) ?? date
        case .month:
            return date.firstDayOfMonth(calendar: calendar) ?? date
        case .day:
            return date.startOfDay(calendar: calendar)
        case .multiday:
            return date.startOfDay(calendar: calendar)
        }
    }
}
