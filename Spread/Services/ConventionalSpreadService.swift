import Foundation

/// Service for finding the best spread for task/note assignment in conventional mode.
///
/// Implements the assignment algorithm that searches from finest to coarsest period
/// using the conventional hierarchy rules:
/// - day-preferred: day → containing multiday → month → year
/// - multiday-preferred: containing multiday → month → year
/// - month-preferred: month → year
/// - year-preferred: year
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
    func findBestSpread(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID? = nil
    ) -> DataModel.Spread? {
        guard task.hasPreferredAssignment else { return nil }
        return findBestSpread(
            preferredDate: task.date,
            preferredPeriod: task.period,
            preferredSpreadID: preferredSpreadID ?? currentDirectMultidaySpreadID(for: task),
            in: spreads
        )
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
    func findBestSpread(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID? = nil
    ) -> DataModel.Spread? {
        findBestSpread(
            preferredDate: note.date,
            preferredPeriod: note.period,
            preferredSpreadID: preferredSpreadID ?? currentDirectMultidaySpreadID(for: note),
            in: spreads
        )
    }

    /// Finds the best spread for an entry based on preferred date and period.
    ///
    /// - Parameters:
    ///   - preferredDate: The entry's preferred date.
    ///   - preferredPeriod: The entry's preferred period.
    ///   - preferredSpreadID: Explicit multiday spread identity when the user
    ///     directly selected one.
    ///   - spreads: The available spreads to search.
    /// - Returns: The best matching spread, or `nil` if no spread matches.
    func findBestSpread(
        preferredDate: Date,
        preferredPeriod: Period,
        preferredSpreadID: UUID? = nil,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        switch preferredPeriod {
        case .day:
            return daySpread(for: preferredDate, in: spreads)
                ?? multidaySpread(for: preferredDate, preferredSpreadID: preferredSpreadID, in: spreads)
                ?? monthSpread(for: preferredDate, in: spreads)
                ?? yearSpread(for: preferredDate, in: spreads)
        case .multiday:
            return multidaySpread(for: preferredDate, preferredSpreadID: preferredSpreadID, in: spreads)
                ?? monthSpread(for: preferredDate, in: spreads)
                ?? yearSpread(for: preferredDate, in: spreads)
        case .month:
            return monthSpread(for: preferredDate, in: spreads)
                ?? yearSpread(for: preferredDate, in: spreads)
        case .year:
            return yearSpread(for: preferredDate, in: spreads)
        }
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

    private func daySpread(for preferredDate: Date, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        let normalizedDate = Period.day.normalizeDate(preferredDate, calendar: calendar)
        return spreads.first { spread in
            spread.period == .day &&
            Period.day.normalizeDate(spread.date, calendar: calendar) == normalizedDate
        }
    }

    private func monthSpread(for preferredDate: Date, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        let normalizedDate = Period.month.normalizeDate(preferredDate, calendar: calendar)
        return spreads.first { spread in
            spread.period == .month &&
            Period.month.normalizeDate(spread.date, calendar: calendar) == normalizedDate
        }
    }

    private func yearSpread(for preferredDate: Date, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        let normalizedDate = Period.year.normalizeDate(preferredDate, calendar: calendar)
        return spreads.first { spread in
            spread.period == .year &&
            Period.year.normalizeDate(spread.date, calendar: calendar) == normalizedDate
        }
    }

    private func multidaySpread(
        for preferredDate: Date,
        preferredSpreadID: UUID?,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        if let preferredSpreadID {
            return spreads.first { spread in
                spread.id == preferredSpreadID && spread.period == .multiday
            }
        }

        return bestContainingMultidaySpread(for: preferredDate, in: spreads)
    }

    func bestContainingMultidaySpread(
        for preferredDate: Date,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        let candidates = spreads.filter { spread in
            spread.period == .multiday && spread.contains(date: preferredDate, calendar: calendar)
        }

        return candidates.sorted(by: isPreferredMultidayCandidate).first
    }

    private func isPreferredMultidayCandidate(_ lhs: DataModel.Spread, _ rhs: DataModel.Spread) -> Bool {
        let lhsLength = rangeLength(for: lhs)
        let rhsLength = rangeLength(for: rhs)
        if lhsLength != rhsLength {
            return lhsLength < rhsLength
        }

        let lhsStart = lhs.startDate ?? lhs.date
        let rhsStart = rhs.startDate ?? rhs.date
        if lhsStart != rhsStart {
            return lhsStart < rhsStart
        }

        let lhsEnd = lhs.endDate ?? lhs.date
        let rhsEnd = rhs.endDate ?? rhs.date
        if lhsEnd != rhsEnd {
            return lhsEnd < rhsEnd
        }

        return lhs.createdDate < rhs.createdDate
    }

    private func rangeLength(for spread: DataModel.Spread) -> Int {
        guard let startDate = spread.startDate, let endDate = spread.endDate else {
            return .max
        }
        return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? .max
    }

    private func currentDirectMultidaySpreadID(for task: DataModel.Task) -> UUID? {
        guard task.period == .multiday else { return nil }
        return task.assignments
            .first(where: { $0.status != .migrated && $0.period == .multiday })?
            .spreadID
    }

    private func currentDirectMultidaySpreadID(for note: DataModel.Note) -> UUID? {
        guard note.period == .multiday else { return nil }
        return note.assignments
            .first(where: { $0.status != .migrated && $0.period == .multiday })?
            .spreadID
    }
}
