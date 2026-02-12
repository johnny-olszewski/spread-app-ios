import Foundation

/// Defines rules for when spreads can be created.
///
/// Implementations validate whether a spread can be created based on
/// date constraints and duplicate detection.
protocol SpreadCreationPolicy {
    /// Validates whether a spread can be created for the given period and date.
    ///
    /// - Parameters:
    ///   - period: The time period for the spread.
    ///   - date: The date for the spread.
    ///   - spreadExists: Whether a spread already exists for this period/date.
    ///   - calendar: The calendar to use for date calculations.
    /// - Returns: `true` if the spread can be created.
    func canCreateSpread(
        period: Period,
        date: Date,
        spreadExists: Bool,
        calendar: Calendar
    ) -> Bool

    /// Validates whether a multiday spread can be created for the given date range.
    ///
    /// - Parameters:
    ///   - startDate: The start date of the multiday range.
    ///   - endDate: The end date of the multiday range.
    ///   - spreadExists: Whether a spread already exists for this range.
    ///   - calendar: The calendar to use for date calculations.
    /// - Returns: `true` if the multiday spread can be created.
    func canCreateMultidaySpread(
        startDate: Date,
        endDate: Date,
        spreadExists: Bool,
        calendar: Calendar
    ) -> Bool
}

/// Standard creation policy enforcing present/future date rules.
///
/// Rules:
/// - Year/Month/Day: Only present or future dates allowed (normalized date >= today's normalized date)
/// - Multiday: Start can be in past if within current week; end must be present or future
/// - No duplicate spreads (same period + normalized date)
struct StandardCreationPolicy: SpreadCreationPolicy {

    // MARK: - Properties

    /// The reference date for determining present/future.
    let today: Date

    /// The user's first day of week preference.
    let firstWeekday: FirstWeekday

    // MARK: - Initialization

    /// Creates a new standard creation policy.
    ///
    /// - Parameters:
    ///   - today: The current date for present/future validation.
    ///   - firstWeekday: The user's first day of week preference.
    init(today: Date, firstWeekday: FirstWeekday) {
        self.today = today
        self.firstWeekday = firstWeekday
    }

    // MARK: - SpreadCreationPolicy

    func canCreateSpread(
        period: Period,
        date: Date,
        spreadExists: Bool,
        calendar: Calendar
    ) -> Bool {
        // Block duplicates
        guard !spreadExists else {
            return false
        }

        // For multiday, use dedicated method
        guard period != .multiday else {
            return false
        }

        // Normalize both dates to the period for comparison
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let normalizedToday = period.normalizeDate(today, calendar: calendar)

        // Allow present or future only
        return normalizedDate >= normalizedToday
    }

    func canCreateMultidaySpread(
        startDate: Date,
        endDate: Date,
        spreadExists: Bool,
        calendar: Calendar
    ) -> Bool {
        // Block duplicates
        guard !spreadExists else {
            return false
        }

        let normalizedStart = startDate.startOfDay(calendar: calendar)
        let normalizedEnd = endDate.startOfDay(calendar: calendar)
        let normalizedToday = today.startOfDay(calendar: calendar)

        // End date must be present or future
        guard normalizedEnd >= normalizedToday else {
            return false
        }

        // If start is present or future, always allowed
        if normalizedStart >= normalizedToday {
            return true
        }

        // Start is in the past - check if within current week
        return isDateWithinCurrentWeek(normalizedStart, calendar: calendar)
    }

    // MARK: - Private Helpers

    /// Checks if a date is within the current week.
    ///
    /// Uses the `firstWeekday` setting to determine week boundaries.
    private func isDateWithinCurrentWeek(_ date: Date, calendar: Calendar) -> Bool {
        guard let currentWeekStart = today.firstDayOfWeek(
            calendar: calendar,
            firstWeekday: firstWeekday
        ) else {
            return false
        }

        guard let currentWeekEnd = today.lastDayOfWeek(
            calendar: calendar,
            firstWeekday: firstWeekday
        ) else {
            return false
        }

        let normalizedDate = date.startOfDay(calendar: calendar)
        let normalizedWeekStart = currentWeekStart.startOfDay(calendar: calendar)
        let normalizedWeekEnd = currentWeekEnd.startOfDay(calendar: calendar)

        return normalizedDate >= normalizedWeekStart && normalizedDate <= normalizedWeekEnd
    }
}
