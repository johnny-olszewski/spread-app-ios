import Foundation

/// Formats migration destination labels for entries that have been migrated to another spread.
///
/// Given a source spread and an entry's assignments, determines where the entry was migrated to
/// and provides a human-readable label for display in entry rows and migrated sections.
struct MigrationDestinationFormatter: Sendable {

    // MARK: - Properties

    /// The calendar for date calculations.
    let calendar: Calendar

    // MARK: - Formatting

    /// Returns a migration destination label for a task relative to a source spread.
    ///
    /// Searches for assignments with smaller (more specific) periods than the source spread,
    /// indicating the task was migrated down the hierarchy.
    ///
    /// - Parameters:
    ///   - task: The task to find a migration destination for.
    ///   - sourceSpread: The spread the task was migrated from.
    /// - Returns: A formatted destination string, or `nil` if no destination is found.
    func destination(for task: DataModel.Task, from sourceSpread: DataModel.Spread) -> String? {
        destination(
            assignments: task.assignments.map { AssignmentInfo(period: $0.period, date: $0.date) },
            sourcePeriod: sourceSpread.period
        )
    }

    /// Returns a migration destination label for a note relative to a source spread.
    ///
    /// - Parameters:
    ///   - note: The note to find a migration destination for.
    ///   - sourceSpread: The spread the note was migrated from.
    /// - Returns: A formatted destination string, or `nil` if no destination is found.
    func destination(for note: DataModel.Note, from sourceSpread: DataModel.Spread) -> String? {
        destination(
            assignments: note.assignments.map { AssignmentInfo(period: $0.period, date: $0.date) },
            sourcePeriod: sourceSpread.period
        )
    }

    // MARK: - Private

    /// Lightweight assignment info for destination lookup.
    private struct AssignmentInfo {
        let period: Period
        let date: Date
    }

    /// Finds the migration destination from a set of assignments relative to a source period.
    ///
    /// Algorithm: Find assignments with smaller period values (more specific) than the source,
    /// then pick the most specific (smallest period value) as the destination.
    private func destination(assignments: [AssignmentInfo], sourcePeriod: Period) -> String? {
        let laterAssignments = assignments.filter { $0.period.rawValue < sourcePeriod.rawValue }

        guard let destination = laterAssignments.sorted(by: { $0.period.rawValue < $1.period.rawValue }).first else {
            return nil
        }

        return formatDestination(period: destination.period, date: destination.date)
    }

    /// Formats a destination period and date into a human-readable label.
    ///
    /// - Year: "2026"
    /// - Month: "Feb 26"
    /// - Day: "2/10/26"
    /// - Multiday: "2/10+"
    private func formatDestination(period: Period, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch period {
        case .year:
            let year = calendar.component(.year, from: date)
            return "\(year)"
        case .month:
            formatter.dateFormat = "MMM yy"
            return formatter.string(from: date)
        case .day:
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        case .multiday:
            formatter.dateFormat = "M/d"
            return formatter.string(from: date) + "+"
        }
    }
}
