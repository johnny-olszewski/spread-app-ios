import struct Foundation.Calendar
import struct Foundation.Date

/// Assignment state for a task on a spread.
struct TaskAssignment: Codable, Hashable {
    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// The status of the task on this spread.
    var status: DataModel.Task.Status

    /// Determines whether this assignment matches a spread.
    ///
    /// - Parameters:
    ///   - period: The spread's time period.
    ///   - date: The spread's normalized date.
    ///   - calendar: The calendar to use for date normalization.
    /// - Returns: `true` if the assignment matches the spread.
    func matches(period: Period, date: Date, calendar: Calendar) -> Bool {
        EntryAssignment(period: self.period, date: self.date)
            .matches(period: period, date: date, calendar: calendar)
    }
}
