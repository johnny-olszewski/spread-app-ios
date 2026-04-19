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
            assignment.matches(period: source.period, date: source.date, calendar: calendar)
        }) else {
            return nil
        }

        return mostGranularValidDestination(
            for: task,
            spreads: spreads,
            sourceRank: source.period.granularityRank
        )
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

        guard destinationMatchesDesiredPath(destination, forDesiredDate: task.date) else {
            return nil
        }

        guard destination.period.granularityRank <= task.period.granularityRank else {
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

        guard let bestDestination = mostGranularValidDestination(
            for: task,
            spreads: spreads,
            sourceRank: sourceKey.sourceRank
        ) else {
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
                    spread.period == assignment.period &&
                    spread.period.normalizeDate(spread.date, calendar: calendar) ==
                    assignment.period.normalizeDate(assignment.date, calendar: calendar)
                })
            }
            .filter { spread in
                guard let excludedSpread else { return true }
                return spread.id != excludedSpread.id
            }
            .max { lhs, rhs in
                if lhs.period.granularityRank == rhs.period.granularityRank {
                    return lhs.date < rhs.date
                }
                return lhs.period.granularityRank < rhs.period.granularityRank
            }
    }

    private func destinationMatchesDesiredPath(
        _ destination: DataModel.Spread,
        forDesiredDate desiredDate: Date
    ) -> Bool {
        destination.period.normalizeDate(destination.date, calendar: calendar) ==
        destination.period.normalizeDate(desiredDate, calendar: calendar)
    }

    private func mostGranularValidDestination(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        sourceRank: Int
    ) -> DataModel.Spread? {
        guard task.hasPreferredAssignment else { return nil }
        return spreads
            .filter { spread in
                spread.period.canHaveTasksAssigned &&
                destinationMatchesDesiredPath(spread, forDesiredDate: task.date) &&
                spread.period.granularityRank <= task.period.granularityRank &&
                spread.period.granularityRank > sourceRank
            }
            .max { lhs, rhs in
                lhs.period.granularityRank < rhs.period.granularityRank
            }
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
}
