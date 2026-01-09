import struct Foundation.Calendar
import struct Foundation.Date

/// Assignment metadata for an entry on a spread.
struct EntryAssignment: Codable, Hashable {
    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// Determines whether this assignment matches a spread.
    ///
    /// - Parameters:
    ///   - period: The spread's time period.
    ///   - date: The spread's normalized date.
    ///   - calendar: The calendar to use for date normalization.
    /// - Returns: `true` if the assignment matches the spread.
    func matches(period: Period, date: Date, calendar: Calendar) -> Bool {
        guard self.period == period else { return false }
        let normalizedSelf = period.normalizeDate(self.date, calendar: calendar)
        let normalizedOther = period.normalizeDate(date, calendar: calendar)
        return normalizedSelf == normalizedOther
    }
}
