import Foundation

extension JournalManager {

    /// Returns the most contextually relevant spread for a given date.
    ///
    /// Delegates to `[DataModel.Spread].bestSpread(for:calendar:)` using the journal's
    /// current spread list and calendar.
    ///
    /// - Parameter date: The reference date. Pass `today` for initial-selection and navigation purposes.
    /// - Returns: The best matching spread, or `nil` if no spread contains `date`.
    func bestSpread(for date: Date) -> DataModel.Spread? {
        spreads.bestSpread(for: date, calendar: calendar)
    }
}

extension [DataModel.Spread] {

    /// Returns the most contextually relevant spread for a given date using a priority cascade.
    ///
    /// Selection priority:
    /// 1. Day spread whose date matches `date`
    /// 2. Multiday spread whose range contains `date` (narrowest range wins; tiebreakers: earliest start, earliest end, earliest creation)
    /// 3. Month spread containing `date`
    /// 4. Year spread containing `date`
    /// 5. `nil` if no spread contains `date`
    func bestSpread(for date: Date, calendar: Calendar) -> DataModel.Spread? {
        if let day = first(where: { $0.period == .day && $0.contains(date: date, calendar: calendar) }) {
            return day
        }

        if let multiday = bestMultidaySpread(for: date, calendar: calendar) {
            return multiday
        }

        if let month = first(where: { $0.period == .month && $0.contains(date: date, calendar: calendar) }) {
            return month
        }

        return first(where: { $0.period == .year && $0.contains(date: date, calendar: calendar) })
    }

    // MARK: - Private

    private func bestMultidaySpread(for date: Date, calendar: Calendar) -> DataModel.Spread? {
        let candidates = filter { $0.period == .multiday && $0.contains(date: date, calendar: calendar) }
        guard !candidates.isEmpty else { return nil }

        return candidates.min { lhs, rhs in
            let lhsLength = rangeLength(of: lhs, calendar: calendar)
            let rhsLength = rangeLength(of: rhs, calendar: calendar)
            if lhsLength != rhsLength { return lhsLength < rhsLength }

            guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else { return lhs.startDate != nil }
            if lhsStart != rhsStart { return lhsStart < rhsStart }

            guard let lhsEnd = lhs.endDate, let rhsEnd = rhs.endDate else { return lhs.endDate != nil }
            if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }

            return lhs.createdDate < rhs.createdDate
        }
    }

    private func rangeLength(of spread: DataModel.Spread, calendar: Calendar) -> Int {
        guard let start = spread.startDate, let end = spread.endDate else { return .max }
        return calendar.dateComponents([.day], from: start, to: end).day ?? .max
    }
}
