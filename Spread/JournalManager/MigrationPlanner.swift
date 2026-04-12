import Foundation

protocol MigrationPlanner {
    func migrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        bujoMode: BujoMode,
        to destination: DataModel.Spread
    ) -> [MigrationCandidate]

    func migrationDestination(
        for task: DataModel.Task,
        on source: DataModel.Spread,
        spreads: [DataModel.Spread],
        bujoMode: BujoMode
    ) -> DataModel.Spread?

    func parentHierarchyMigrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        bujoMode: BujoMode,
        to destination: DataModel.Spread
    ) -> [MigrationCandidate]

    func currentDestinationSpread(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread?
    ) -> DataModel.Spread?

    func currentDisplayedSpread(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread?
    ) -> DataModel.Spread?
}

struct StandardMigrationPlanner: MigrationPlanner {
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
        guard task.status == .open else {
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
        spreads
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
