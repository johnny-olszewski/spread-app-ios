import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.DateComponents

extension Date {
    // MARK: - Period Normalization

    /// Returns the first day of the year containing this date.
    ///
    /// Uses the provided calendar for date calculations.
    /// - Parameter calendar: The calendar to use for date calculations.
    /// - Returns: The first day of the year, or `nil` if calculation fails.
    func firstDayOfYear(calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components)
    }

    /// Returns the first day of the month containing this date.
    ///
    /// Uses the provided calendar for date calculations.
    /// - Parameter calendar: The calendar to use for date calculations.
    /// - Returns: The first day of the month, or `nil` if calculation fails.
    func firstDayOfMonth(calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)
    }

    /// Returns the start of the day for this date.
    ///
    /// Uses the provided calendar for date calculations.
    /// - Parameter calendar: The calendar to use for date calculations.
    /// - Returns: The start of the day (midnight).
    func startOfDay(calendar: Calendar) -> Date {
        calendar.startOfDay(for: self)
    }

    // MARK: - Date Construction

    /// Creates a date from year, month, and day components.
    ///
    /// Uses the provided calendar for date calculations.
    /// - Parameters:
    ///   - calendar: The calendar to use for date construction.
    ///   - year: The year component.
    ///   - month: The month component (1-12).
    ///   - day: The day component (1-31).
    /// - Returns: The constructed date, or `nil` if the components are invalid.
    static func from(
        calendar: Calendar,
        year: Int,
        month: Int,
        day: Int
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    // MARK: - Week Calculations

    /// Returns the first day of the week containing this date.
    ///
    /// The first day is determined by the provided `firstWeekday` setting.
    /// - Parameters:
    ///   - calendar: The calendar to use for date calculations.
    ///   - firstWeekday: The first day of the week setting.
    /// - Returns: The first day of the week, or `nil` if calculation fails.
    func firstDayOfWeek(calendar: Calendar, firstWeekday: FirstWeekday) -> Date? {
        var adjustedCalendar = calendar
        adjustedCalendar.firstWeekday = firstWeekday.weekdayValue(using: calendar)

        let components = adjustedCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return adjustedCalendar.date(from: components)
    }

    /// Returns the last day of the week containing this date.
    ///
    /// The week boundaries are determined by the provided `firstWeekday` setting.
    /// - Parameters:
    ///   - calendar: The calendar to use for date calculations.
    ///   - firstWeekday: The first day of the week setting.
    /// - Returns: The last day of the week, or `nil` if calculation fails.
    func lastDayOfWeek(calendar: Calendar, firstWeekday: FirstWeekday) -> Date? {
        guard let firstDay = firstDayOfWeek(calendar: calendar, firstWeekday: firstWeekday) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: 6, to: firstDay)
    }
}
