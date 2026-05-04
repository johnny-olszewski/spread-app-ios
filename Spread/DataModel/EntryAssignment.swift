import Foundation

/// Shared assignment data used for spread matching.
protocol AssignmentMatchable {
    /// The spread period for this assignment.
    var period: Period { get }

    /// The spread date for this assignment.
    var date: Date { get }

    /// Explicit spread identity for assignments whose ownership cannot be safely
    /// inferred from period/date alone.
    var spreadID: UUID? { get }

    /// Determines whether this assignment matches a spread.
    ///
    /// - Parameters:
    ///   - period: The spread's time period.
    ///   - date: The spread's normalized date.
    ///   - spreadID: The explicit spread identity, if available.
    ///   - calendar: The calendar to use for date normalization.
    /// - Returns: `true` if the assignment matches the spread.
    func matches(period: Period, date: Date, spreadID: UUID?, calendar: Calendar) -> Bool
}

extension AssignmentMatchable {
    func matches(period: Period, date: Date, spreadID: UUID? = nil, calendar: Calendar) -> Bool {
        if let spreadID, let assignmentSpreadID = self.spreadID {
            return assignmentSpreadID == spreadID
        }

        guard self.period == period else { return false }
        let normalizedSelf = period.normalizeDate(self.date, calendar: calendar)
        let normalizedOther = period.normalizeDate(date, calendar: calendar)
        return normalizedSelf == normalizedOther
    }

    func matches(spread: DataModel.Spread, calendar: Calendar) -> Bool {
        matches(
            period: spread.period,
            date: spread.date,
            spreadID: spread.id,
            calendar: calendar
        )
    }
}
