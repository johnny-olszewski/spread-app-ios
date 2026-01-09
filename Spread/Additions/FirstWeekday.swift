import struct Foundation.Calendar
import struct Foundation.Locale

/// User preference for the first day of the week.
///
/// Used by multiday preset calculations and week-based date operations.
/// Persisted in user settings (SPRD-20).
enum FirstWeekday: String, CaseIterable {
    /// Use the system's locale-based first weekday.
    case systemDefault

    /// Sunday (weekday value 1).
    case sunday

    /// Monday (weekday value 2).
    case monday

    // MARK: - Display

    /// The display name for this setting.
    var displayName: String {
        switch self {
        case .systemDefault:
            return "System Default"
        case .sunday:
            return "Sunday"
        case .monday:
            return "Monday"
        }
    }

    // MARK: - Calendar Integration

    /// Returns the weekday value (1-7) for use with Calendar.
    ///
    /// For `.systemDefault`, uses the provided calendar's locale to determine
    /// the first weekday.
    /// - Parameter calendar: The calendar to use for system default resolution.
    /// - Returns: The weekday value (1 = Sunday, 2 = Monday, etc.).
    func weekdayValue(using calendar: Calendar) -> Int {
        switch self {
        case .systemDefault:
            return calendar.firstWeekday
        case .sunday:
            return 1
        case .monday:
            return 2
        }
    }

    /// Creates a calendar configured with this first weekday setting.
    ///
    /// - Parameter baseCalendar: The calendar to use as a base.
    /// - Returns: A new calendar with the first weekday configured.
    func configuredCalendar(from baseCalendar: Calendar) -> Calendar {
        var calendar = baseCalendar
        calendar.firstWeekday = weekdayValue(using: baseCalendar)
        return calendar
    }
}
