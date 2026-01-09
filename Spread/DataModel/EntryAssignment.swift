import struct Foundation.Calendar
import struct Foundation.Date

/// Shared assignment data used for spread matching.
protocol AssignmentMatchable {
    /// The spread period for this assignment.
    var period: Period { get }

    /// The spread date for this assignment.
    var date: Date { get }

    /// Determines whether this assignment matches a spread.
    ///
    /// - Parameters:
    ///   - period: The spread's time period.
    ///   - date: The spread's normalized date.
    ///   - calendar: The calendar to use for date normalization.
    /// - Returns: `true` if the assignment matches the spread.
    func matches(period: Period, date: Date, calendar: Calendar) -> Bool
}

extension AssignmentMatchable {
    func matches(period: Period, date: Date, calendar: Calendar) -> Bool {
        guard self.period == period else { return false }
        let normalizedSelf = period.normalizeDate(self.date, calendar: calendar)
        let normalizedOther = period.normalizeDate(date, calendar: calendar)
        return normalizedSelf == normalizedOther
    }
}
