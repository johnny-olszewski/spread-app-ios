import struct Foundation.Calendar
import struct Foundation.Date

/// Service for finding the best spread for task/note assignment in conventional mode.
///
/// Implements the assignment algorithm that searches from finest to coarsest period
/// (day → month → year) to find a matching spread for an entry's preferred date.
/// Multiday spreads are skipped as they aggregate entries by date range rather than
/// direct assignment.
struct ConventionalSpreadService {

    // MARK: - Properties

    /// The calendar used for date calculations.
    let calendar: Calendar

    // MARK: - Task/Note Assignment

    /// Finds the best spread for a task based on its preferred date and period.
    ///
    /// Searches from the task's preferred period up through coarser periods (day → month → year)
    /// to find the first matching spread. Multiday spreads are skipped.
    ///
    /// - Parameters:
    ///   - task: The task to find a spread for.
    ///   - spreads: The available spreads to search.
    /// - Returns: The best matching spread, or `nil` if no spread matches (entry goes to Inbox).
    func findBestSpread(for task: DataModel.Task, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        findBestSpread(preferredDate: task.date, preferredPeriod: task.period, in: spreads)
    }

    /// Finds the best spread for a note based on its preferred date and period.
    ///
    /// Searches from the note's preferred period up through coarser periods (day → month → year)
    /// to find the first matching spread. Multiday spreads are skipped.
    ///
    /// - Parameters:
    ///   - note: The note to find a spread for.
    ///   - spreads: The available spreads to search.
    /// - Returns: The best matching spread, or `nil` if no spread matches (entry goes to Inbox).
    func findBestSpread(for note: DataModel.Note, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        findBestSpread(preferredDate: note.date, preferredPeriod: note.period, in: spreads)
    }

    /// Finds the best spread for an entry based on preferred date and period.
    ///
    /// Algorithm:
    /// 1. Start at the preferred period
    /// 2. Look for a spread matching the normalized date at that period
    /// 3. If not found, move to parent period (day → month → year)
    /// 4. Repeat until a match is found or no more parent periods
    /// 5. Skip multiday spreads (they don't accept direct assignments)
    ///
    /// - Parameters:
    ///   - preferredDate: The entry's preferred date.
    ///   - preferredPeriod: The entry's preferred period.
    ///   - spreads: The available spreads to search.
    /// - Returns: The best matching spread, or `nil` if no spread matches.
    private func findBestSpread(
        preferredDate: Date,
        preferredPeriod: Period,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        // Filter to only assignable spreads (exclude multiday)
        let assignableSpreads = spreads.filter { $0.period.canHaveTasksAssigned }

        // Start at preferred period and walk up the hierarchy
        var currentPeriod: Period? = preferredPeriod

        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(preferredDate, calendar: calendar)

            // Look for a spread matching this period and normalized date
            if let matchingSpread = assignableSpreads.first(where: { spread in
                spread.period == period &&
                spread.period.normalizeDate(spread.date, calendar: calendar) == normalizedDate
            }) {
                return matchingSpread
            }

            // Move to parent period
            currentPeriod = period.parentPeriod
        }

        return nil
    }

    // MARK: - Event Visibility

    /// Determines if an event appears on a spread based on date range overlap.
    ///
    /// Events use computed visibility rather than assignments. An event appears on
    /// a spread if its date range overlaps with the spread's time period.
    ///
    /// - Parameters:
    ///   - event: The event to check.
    ///   - spread: The spread to check visibility on.
    /// - Returns: `true` if the event should appear on the spread.
    func eventAppearsOnSpread(_ event: DataModel.Event, spread: DataModel.Spread) -> Bool {
        if spread.period == .multiday {
            // For multiday spreads, check if event overlaps with the custom range
            guard let startDate = spread.startDate, let endDate = spread.endDate else {
                return false
            }
            let eventStart = event.startDate.startOfDay(calendar: calendar)
            let eventEnd = event.endDate.startOfDay(calendar: calendar)
            return eventStart <= endDate && eventEnd >= startDate
        }

        return event.appearsOn(period: spread.period, date: spread.date, calendar: calendar)
    }
}
