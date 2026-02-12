import Foundation

/// Organizes spreads into a hierarchical structure for display.
///
/// Converts a flat list of spreads into a year → month → day hierarchy,
/// with proper chronological ordering and support for initial selection.
struct SpreadHierarchyOrganizer {

    // MARK: - Nested Types

    /// A year node in the hierarchy containing month children.
    struct YearNode: Identifiable {
        let id: UUID
        let spread: DataModel.Spread
        var months: [MonthNode]

        init(spread: DataModel.Spread, months: [MonthNode] = []) {
            self.id = spread.id
            self.spread = spread
            self.months = months
        }
    }

    /// A month node in the hierarchy containing day/multiday children.
    struct MonthNode: Identifiable {
        let id: UUID
        let spread: DataModel.Spread
        var days: [DayNode]

        init(spread: DataModel.Spread, days: [DayNode] = []) {
            self.id = spread.id
            self.spread = spread
            self.days = days
        }
    }

    /// A day or multiday node in the hierarchy (leaf level).
    struct DayNode: Identifiable {
        let id: UUID
        let spread: DataModel.Spread

        init(spread: DataModel.Spread) {
            self.id = spread.id
            self.spread = spread
        }
    }

    // MARK: - Properties

    /// The organized year nodes.
    let years: [YearNode]

    /// Calendar used for date comparisons.
    private let calendar: Calendar

    /// All spreads, for quick lookup.
    private let allSpreads: [DataModel.Spread]

    // MARK: - Initialization

    /// Creates an organizer from a list of spreads.
    ///
    /// - Parameters:
    ///   - spreads: The spreads to organize.
    ///   - calendar: The calendar for date calculations.
    init(spreads: [DataModel.Spread], calendar: Calendar) {
        self.calendar = calendar
        self.allSpreads = spreads
        self.years = Self.buildHierarchy(from: spreads, calendar: calendar)
    }

    // MARK: - Hierarchy Building

    private static func buildHierarchy(
        from spreads: [DataModel.Spread],
        calendar: Calendar
    ) -> [YearNode] {
        // Separate spreads by period
        let yearSpreads = spreads.filter { $0.period == .year }
        let monthSpreads = spreads.filter { $0.period == .month }
        let daySpreads = spreads.filter { $0.period == .day }
        let multidaySpreads = spreads.filter { $0.period == .multiday }

        // Build year nodes with their children
        var yearNodes: [YearNode] = yearSpreads.map { YearNode(spread: $0) }

        // Sort years chronologically
        yearNodes.sort { calendar.compare($0.spread.date, to: $1.spread.date, toGranularity: .year) == .orderedAscending }

        // Associate months with years
        for i in yearNodes.indices {
            let yearComponent = calendar.component(.year, from: yearNodes[i].spread.date)

            // Find months in this year
            var monthNodes: [MonthNode] = monthSpreads
                .filter { calendar.component(.year, from: $0.date) == yearComponent }
                .map { MonthNode(spread: $0) }

            // Sort months chronologically
            monthNodes.sort { calendar.compare($0.spread.date, to: $1.spread.date, toGranularity: .month) == .orderedAscending }

            // Associate days and multiday with months
            for j in monthNodes.indices {
                let monthComponent = calendar.component(.month, from: monthNodes[j].spread.date)

                // Find days in this month
                let dayNodes: [DayNode] = daySpreads
                    .filter {
                        calendar.component(.year, from: $0.date) == yearComponent &&
                        calendar.component(.month, from: $0.date) == monthComponent
                    }
                    .map { DayNode(spread: $0) }

                // Find multiday spreads that start in this month
                let multidayNodes: [DayNode] = multidaySpreads
                    .filter {
                        guard let startDate = $0.startDate else { return false }
                        return calendar.component(.year, from: startDate) == yearComponent &&
                               calendar.component(.month, from: startDate) == monthComponent
                    }
                    .map { DayNode(spread: $0) }

                // Combine and sort by start date
                var allDayNodes = dayNodes + multidayNodes
                allDayNodes.sort { $0.spread.date < $1.spread.date }

                monthNodes[j].days = allDayNodes
            }

            yearNodes[i].months = monthNodes
        }

        return yearNodes
    }

    // MARK: - Initial Selection

    /// Finds the initial selection for a given date.
    ///
    /// Selection priority:
    /// 1. Day spread containing the date
    /// 2. Multiday spread containing the date (with tiebreakers)
    /// 3. Month spread containing the date
    /// 4. Year spread containing the date
    /// 5. nil if no spread contains the date
    ///
    /// - Parameter date: The reference date (typically today).
    /// - Returns: The spread to select initially, or nil.
    func initialSelection(for date: Date) -> DataModel.Spread? {
        // Priority 1: Day spread containing today
        if let daySpread = findDaySpread(containing: date) {
            return daySpread
        }

        // Priority 2: Multiday spread containing today
        if let multidaySpread = findBestMultidaySpread(containing: date) {
            return multidaySpread
        }

        // Priority 3: Month spread containing today
        if let monthSpread = findMonthSpread(containing: date) {
            return monthSpread
        }

        // Priority 4: Year spread containing today
        if let yearSpread = findYearSpread(containing: date) {
            return yearSpread
        }

        return nil
    }

    // MARK: - Spread Finding Helpers

    private func findDaySpread(containing date: Date) -> DataModel.Spread? {
        allSpreads.first { $0.period == .day && $0.contains(date: date, calendar: calendar) }
    }

    private func findMonthSpread(containing date: Date) -> DataModel.Spread? {
        allSpreads.first { $0.period == .month && $0.contains(date: date, calendar: calendar) }
    }

    private func findYearSpread(containing date: Date) -> DataModel.Spread? {
        allSpreads.first { $0.period == .year && $0.contains(date: date, calendar: calendar) }
    }

    private func findBestMultidaySpread(containing date: Date) -> DataModel.Spread? {
        let candidates = allSpreads.filter {
            $0.period == .multiday && $0.contains(date: date, calendar: calendar)
        }

        guard !candidates.isEmpty else { return nil }

        // Apply tiebreakers: earliest start, earliest end, earliest creation
        return candidates.sorted { lhs, rhs in
            // Compare start dates
            guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else {
                return lhs.startDate != nil
            }
            if lhsStart != rhsStart {
                return lhsStart < rhsStart
            }

            // Compare end dates
            guard let lhsEnd = lhs.endDate, let rhsEnd = rhs.endDate else {
                return lhs.endDate != nil
            }
            if lhsEnd != rhsEnd {
                return lhsEnd < rhsEnd
            }

            // Compare creation dates
            return lhs.createdDate < rhs.createdDate
        }.first
    }
}
