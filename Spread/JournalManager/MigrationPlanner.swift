import Foundation

/// Determines which tasks are eligible for migration and where they should go.
///
/// Migration eligibility is based on three constraints:
/// 1. **Direction**: A task can only move to a spread with a higher granularity rank than its current source.
///    (e.g., month → day is forward; day → month is not).
/// 2. **Path alignment**: The destination's normalized date must fall within the task's desired date hierarchy
///    (e.g., a task with a desired July date can migrate to a July month spread or a July day spread).
/// 3. **Ceiling**: The destination's period cannot be more granular than the task's preferred period
///    (e.g., a monthly task cannot migrate to a day spread).
///
/// Only used in conventional mode — traditional mode does not have explicit spreads for migration.
protocol MigrationPlanner {
    /// Returns all tasks eligible to be migrated to the given destination spread.
    ///
    /// Only produces candidates in conventional mode. Returns an empty array for non-assignable
    /// periods (e.g., multiday) or when not in conventional mode.
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - spreads: All existing spreads.
    ///   - bujoMode: The current BuJo mode; candidates are only produced in `.conventional`.
    ///   - destination: The target spread.
    /// - Returns: `MigrationCandidate` values for each eligible task.
    func migrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        bujoMode: BujoMode,
        to destination: DataModel.Spread
    ) -> [MigrationCandidate]

    /// Returns the best destination spread for an inline source-side migration affordance.
    ///
    /// This is used to decide whether to show a migration arrow on a task row when it is
    /// displayed on `source`. Returns `nil` if the task is not open, not on `source`, or
    /// if no valid forward destination exists.
    ///
    /// - Parameters:
    ///   - task: The task to evaluate.
    ///   - source: The spread the task is currently displayed on.
    ///   - spreads: All existing spreads.
    ///   - bujoMode: The current BuJo mode.
    /// - Returns: The most granular valid destination spread, or `nil`.
    func migrationDestination(
        for task: DataModel.Task,
        on source: DataModel.Spread,
        spreads: [DataModel.Spread],
        bujoMode: BujoMode
    ) -> DataModel.Spread?

    /// Returns migration candidates that originate exclusively from the destination's parent hierarchy.
    ///
    /// Filters `migrationCandidates` to those whose current source spread is a direct ancestor of the
    /// destination (e.g., for a day spread, parents are month and year). Inbox-origin tasks are excluded.
    /// Results are sorted alphabetically by task title.
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - spreads: All existing spreads.
    ///   - bujoMode: The current BuJo mode.
    ///   - destination: The target spread.
    /// - Returns: Sorted `MigrationCandidate` values from parent spreads only.
    func parentHierarchyMigrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        bujoMode: BujoMode,
        to destination: DataModel.Spread
    ) -> [MigrationCandidate]

    /// Returns the spread where the task has an open (`.open`) assignment.
    ///
    /// When multiple open assignments exist (which can occur transiently), the most granular spread
    /// with the most recent date is returned. An optional `excludedSpread` allows callers to filter
    /// out the spread being deleted.
    ///
    /// - Parameters:
    ///   - task: The task to inspect.
    ///   - spreads: All existing spreads.
    ///   - excludedSpread: A spread to exclude from the search, or `nil`.
    /// - Returns: The most granular spread with an open assignment, or `nil`.
    func currentDestinationSpread(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread?
    ) -> DataModel.Spread?

    /// Returns the spread where the task is currently visible (non-migrated assignment).
    ///
    /// Similar to `currentDestinationSpread` but includes completed assignments as well
    /// as open ones. Used to show the task's current location in migration review UIs
    /// without restricting to strictly open tasks.
    ///
    /// - Parameters:
    ///   - task: The task to inspect.
    ///   - spreads: All existing spreads.
    ///   - excludedSpread: A spread to exclude from the search, or `nil`.
    /// - Returns: The most granular spread with a non-migrated assignment, or `nil`.
    func currentDisplayedSpread(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread?
    ) -> DataModel.Spread?
}

/// Standard implementation of `MigrationPlanner` using calendar-based date alignment.
struct StandardMigrationPlanner: MigrationPlanner {
    /// The calendar used for date normalization and parent hierarchy traversal.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func migrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        bujoMode: BujoMode,
        to destination: DataModel.Spread
    ) -> [MigrationCandidate] {
        guard bujoMode == .conventional, destination.period.canHaveTasksAssigned else {
            return []
        }

        return tasks.compactMap { task in
            migrationCandidate(for: task, spreads: spreads, to: destination)
        }
    }

    func migrationDestination(
        for task: DataModel.Task,
        on source: DataModel.Spread,
        spreads: [DataModel.Spread],
        bujoMode: BujoMode
    ) -> DataModel.Spread? {
        guard bujoMode == .conventional,
              source.period.canHaveTasksAssigned,
              task.status == .open else {
            return nil
        }

        guard task.assignments.contains(where: { assignment in
            assignment.status == .open &&
            assignment.matches(spread: source, calendar: calendar)
        }) else {
            return nil
        }

        guard let destination = mostGranularValidDestination(for: task, spreads: spreads),
              destination.period.granularityRank > source.period.granularityRank else {
            return nil
        }

        return destination
    }

    func parentHierarchyMigrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        bujoMode: BujoMode,
        to destination: DataModel.Spread
    ) -> [MigrationCandidate] {
        let parentSpreadIDs = Set(parentHierarchySpreads(for: destination, spreads: spreads).map(\.id))

        return migrationCandidates(
            tasks: tasks,
            spreads: spreads,
            bujoMode: bujoMode,
            to: destination
        )
        .filter { candidate in
            guard let sourceSpread = candidate.sourceSpread else { return false }
            return parentSpreadIDs.contains(sourceSpread.id)
        }
        .sorted { lhs, rhs in
            lhs.task.title.localizedCaseInsensitiveCompare(rhs.task.title) == .orderedAscending
        }
    }

    func currentDestinationSpread(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        candidateSpreads(
            for: task,
            spreads: spreads,
            excluding: excludedSpread
        ) { $0.status == .open }
    }

    func currentDisplayedSpread(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        candidateSpreads(
            for: task,
            spreads: spreads,
            excluding: excludedSpread
        ) { $0.status != .migrated }
    }

    private func migrationCandidate(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        to destination: DataModel.Spread
    ) -> MigrationCandidate? {
        guard task.status == .open, task.hasPreferredAssignment else {
            return nil
        }

        let sourceKey: TaskReviewSourceKey
        let sourceSpread: DataModel.Spread?
        if let openSpread = currentDestinationSpread(for: task, spreads: spreads, excluding: nil) {
            sourceKey = sourceSpreadSource(openSpread)
            sourceSpread = openSpread
        } else {
            sourceKey = .init(kind: .inbox)
            sourceSpread = nil
        }

        guard destination.period.granularityRank > sourceKey.sourceRank else {
            return nil
        }

        guard let bestDestination = mostGranularValidDestination(for: task, spreads: spreads) else {
            return nil
        }

        guard bestDestination.id == destination.id else {
            return nil
        }

        return MigrationCandidate(
            task: task,
            sourceKey: sourceKey,
            sourceSpread: sourceSpread,
            destination: destination
        )
    }

    private func candidateSpreads(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread?,
        matching statusPredicate: (TaskAssignment) -> Bool
    ) -> DataModel.Spread? {
        task.assignments
            .filter(statusPredicate)
            .compactMap { assignment in
                spreads.first(where: { spread in
                    assignment.matches(spread: spread, calendar: calendar)
                })
            }
            .filter { spread in
                guard let excludedSpread else { return true }
                return spread.id != excludedSpread.id
            }
            .sorted(by: preferredSpreadOrder)
            .last
    }

    private func mostGranularValidDestination(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        guard task.hasPreferredAssignment else { return nil }
        return spreadService.findBestSpread(for: task, in: spreads)
    }

    private func sourceSpreadSource(_ spread: DataModel.Spread) -> TaskReviewSourceKey {
        TaskReviewSourceKey(
            kind: .spread(
                id: spread.id,
                period: spread.period,
                date: spread.period.normalizeDate(spread.date, calendar: calendar)
            )
        )
    }

    private func parentHierarchySpreads(
        for destination: DataModel.Spread,
        spreads: [DataModel.Spread]
    ) -> [DataModel.Spread] {
        if destination.period == .multiday {
            return parentHierarchySpreadsForMultiday(destination, spreads: spreads)
        }

        var parentSpreads: [DataModel.Spread] = []
        var currentPeriod = destination.period.parentPeriod

        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(destination.date, calendar: calendar)
            if let spread = spreads.first(where: { existingSpread in
                existingSpread.period == period &&
                existingSpread.period.normalizeDate(existingSpread.date, calendar: calendar) == normalizedDate
            }) {
                parentSpreads.append(spread)
            }
            currentPeriod = period.parentPeriod
        }

        return parentSpreads
    }

    private func parentHierarchySpreadsForMultiday(
        _ destination: DataModel.Spread,
        spreads: [DataModel.Spread]
    ) -> [DataModel.Spread] {
        guard let startDate = destination.startDate, let endDate = destination.endDate else { return [] }

        var parents: [DataModel.Spread] = []
        var monthKeys = Set<Date>()
        var cursor = Period.month.normalizeDate(startDate, calendar: calendar)
        let finalMonth = Period.month.normalizeDate(endDate, calendar: calendar)

        while cursor <= finalMonth {
            monthKeys.insert(cursor)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = Period.month.normalizeDate(nextMonth, calendar: calendar)
        }

        parents.append(contentsOf: spreads.filter { spread in
            spread.period == .month && monthKeys.contains(Period.month.normalizeDate(spread.date, calendar: calendar))
        })

        let yearKeys = Set(monthKeys.map { Period.year.normalizeDate($0, calendar: calendar) })
        parents.append(contentsOf: spreads.filter { spread in
            spread.period == .year && yearKeys.contains(Period.year.normalizeDate(spread.date, calendar: calendar))
        })

        return parents.sorted(by: preferredSpreadOrder)
    }

    private func preferredSpreadOrder(_ lhs: DataModel.Spread, _ rhs: DataModel.Spread) -> Bool {
        if lhs.period.granularityRank != rhs.period.granularityRank {
            return lhs.period.granularityRank < rhs.period.granularityRank
        }

        if lhs.period == .multiday, rhs.period == .multiday {
            let lhsLength = rangeLength(for: lhs)
            let rhsLength = rangeLength(for: rhs)
            if lhsLength != rhsLength {
                return lhsLength > rhsLength
            }
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
}
