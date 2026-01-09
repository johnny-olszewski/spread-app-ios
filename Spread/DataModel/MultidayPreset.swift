import struct Foundation.Calendar
import struct Foundation.Date

/// Preset options for creating multiday spreads.
///
/// Computes start and end dates based on the user's first weekday setting.
enum MultidayPreset: CaseIterable {
    /// The current week (Sunday-Saturday or Monday-Sunday based on settings).
    case thisWeek

    /// The following week.
    case nextWeek

    // MARK: - Display

    /// The display name for this preset.
    var displayName: String {
        switch self {
        case .thisWeek:
            return "This Week"
        case .nextWeek:
            return "Next Week"
        }
    }

    // MARK: - Date Calculation

    /// Calculates the date range for this preset.
    ///
    /// - Parameters:
    ///   - today: The reference date (typically today).
    ///   - calendar: The calendar to use for calculations.
    ///   - firstWeekday: The user's first day of week preference.
    /// - Returns: A tuple of (startDate, endDate), or `nil` if calculation fails.
    func dateRange(
        from today: Date,
        calendar: Calendar,
        firstWeekday: FirstWeekday
    ) -> (startDate: Date, endDate: Date)? {
        switch self {
        case .thisWeek:
            guard let startDate = today.firstDayOfWeek(calendar: calendar, firstWeekday: firstWeekday),
                  let endDate = today.lastDayOfWeek(calendar: calendar, firstWeekday: firstWeekday) else {
                return nil
            }
            return (startDate, endDate)

        case .nextWeek:
            guard let thisWeekStart = today.firstDayOfWeek(calendar: calendar, firstWeekday: firstWeekday),
                  let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: thisWeekStart),
                  let nextWeekEnd = calendar.date(byAdding: .day, value: 6, to: nextWeekStart) else {
                return nil
            }
            return (nextWeekStart, nextWeekEnd)
        }
    }
}
