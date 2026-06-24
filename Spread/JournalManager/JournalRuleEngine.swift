import Foundation

/// Consolidated journal business logic: pure or mostly-pure rules over already-loaded
/// spreads/tasks/notes/events, with no repository access of its own.
///
/// Per `Documentation/Specs/JournalManager.md`'s "rule engine" guidance — pure or mostly
/// pure, returning derived models, plans, or mutation decisions without performing
/// repository writes directly. Concrete, no protocol declaration, no "Standard" naming —
/// see the spec's "Decision: Drop protocol-per-logic-seam; protocols are a repository-only
/// boundary." Takes only `calendar`/`today` by direct initialization; callers
/// (`JournalManager`, the future facade, `TaskCoordinator`/`NoteCoordinator`/
/// `SpreadDeletionCoordinator`) own repository access and persist any resulting mutations
/// themselves.
///
/// Consolidates what were previously separate protocol-backed types — data-model
/// building, Inbox resolution, migration planning, overdue evaluation, and task/note
/// assignment reconciliation — into one type, since all of them share this exact
/// dependency shape and are frequently used together (e.g. overdue evaluation already
/// depends on migration planning's `currentDestinationSpread`).
///
/// This is purely additive: zero edits to any existing legacy logic file
/// (`ConventionalJournalDataModelBuilder`, `StandardInboxResolver`,
/// `StandardMigrationPlanner`, `StandardOverdueEvaluator`,
/// `StandardTaskAssignmentReconciler`, `StandardNoteAssignmentReconciler`, or their
/// protocol declarations). `JournalManager` continues to use those types until SPRD-251's
/// cutover.
struct JournalRuleEngine {
    /// The calendar used for date normalization and period boundary computation.
    let calendar: Calendar

    /// The reference date representing today, used by overdue evaluation.
    let today: Date

    /// Creates a rule engine configured with the given calendar and reference date.
    ///
    /// - Parameters:
    ///   - calendar: The calendar used for date normalization and event overlap checks.
    ///   - today: The reference date representing today. Defaults to `.now`; only overdue
    ///     evaluation consults this.
    init(calendar: Calendar, today: Date = .now) {
        self.calendar = calendar
        self.today = today
        
        spreadService = SpreadService(calendar: calendar)
    }

    private var spreadService: SpreadService

    // MARK: - Data Model Building

    /// Builds the journal data model by iterating over each explicit spread and collecting
    /// the tasks, notes, and events that belong to it.
    ///
    /// For every explicit spread, entries are matched via their current non-migrated
    /// assignments. Multiday spreads therefore only show entries explicitly assigned
    /// to that spread. Events are matched by date-range overlap.
    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        var model: JournalDataModel = [:]

        for spread in spreads {
            let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
            var spreadData = SpreadDataModel(spread: spread)
            spreadData.tasks = entriesShownOnSpread(spread, entries: tasks)
            spreadData.notes = entriesShownOnSpread(spread, entries: notes)
            spreadData.events = eventsShownOnSpread(spread, events: events)

            // if this is the first spread for the period
            if model[spread.period] == nil {
                model[spread.period] = [:]
            }
            
            model[spread.period]?[normalizedDate] = spreadData
        }

        return model
    }

    /// Rebuilds one explicit spread surface for scoped `JournalManager` patching.
    ///
    /// Returns `nil` only when the matching explicit spread no longer exists.
    ///
    /// - TODO: [SPRD-249] This does a full `entriesShownOnSpread`/`filter` scan over every
    ///   task/note/event for this one key — O(entries), not O(matched entities). SPRD-249's
    ///   dictionary-keyed reverse index is expected to replace this with an index-bucket
    ///   lookup, same as the legacy `ConventionalJournalDataModelBuilder` this was ported
    ///   from; this task only consolidates the seam, it doesn't change its complexity.
    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel? {
        guard let spread = spreads.first(where: { candidate in
            candidate.period == key.period &&
            candidate.period.normalizeDate(candidate.date, calendar: calendar) == key.date
        }) else {
            return nil
        }

        return SpreadDataModel(
            spread: spread,
            tasks: entriesShownOnSpread(spread, entries: tasks),
            notes: entriesShownOnSpread(spread, entries: notes),
            events: eventsShownOnSpread(spread, events: events)
        )
    }

    /// Returns all conventional surfaces that can display the entry.
    ///
    /// This includes explicit spreads backed by the entry's current non-migrated
    /// assignments. Generic over any `AssignableEntry` (currently `DataModel.Task`/
    /// `DataModel.Note`) so this logic exists once rather than once per entry type.
    func spreadKeys<E: AssignableEntry>(
        for entry: E,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        let explicitKeys: [SpreadDataModelKey] = entry.assignments.compactMap { assignment in
            guard !assignment.isMigrated else { return nil }
            if assignment.period == .multiday,
               let spreadID = assignment.spreadID,
               let spread = spreads.first(where: { $0.id == spreadID }) {
                return SpreadDataModelKey(spread: spread, calendar: calendar)
            }
            return SpreadDataModelKey(period: assignment.period, date: assignment.date, calendar: calendar)
        }
        return Set(explicitKeys)
    }

    /// Returns the canonical derived-model key for an explicit conventional spread.
    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey? {
        SpreadDataModelKey(spread: spread, calendar: calendar)
    }

    /// Returns the entries (tasks or notes) shown on the given spread.
    ///
    /// All periods match entries that have a current non-migrated
    /// assignment for the spread's period and date.
    private func entriesShownOnSpread<E: AssignableEntry>(
        _ spread: DataModel.Spread,
        entries: [E]
    ) -> [E] {
        entries.filter { shouldShowOnSpread($0, for: spread) }
    }

    /// Returns `true` if the entry has a current non-migrated assignment matching the spread.
    private func shouldShowOnSpread<E: AssignableEntry>(
        _ entry: E,
        for spread: DataModel.Spread
    ) -> Bool {
        entry.assignments.contains { assignment in
            !assignment.isMigrated &&
            assignment.matches(spread: spread, calendar: calendar)
        }
    }

    /// Returns the events shown on the given spread, matched by date-range overlap.
    private func eventsShownOnSpread(
        _ spread: DataModel.Spread,
        events: [DataModel.Event]
    ) -> [DataModel.Event] {
        events.filter { spreadService.eventAppearsOnSpread($0, spread: spread) }
    }

    // MARK: - Inbox Resolution

    /// Returns all entries that have no matching spread assignment.
    ///
    /// - Inbox membership is gated by `Entry.isInboxEligible` (SPRD-247's static per-type
    ///   constant — currently `true` for `Task` only). Entries whose type is never
    ///   Inbox-eligible are excluded outright, without consulting assignment matching.
    /// - Cancelled entries are excluded regardless of type eligibility — they are no longer
    ///   actionable. This is a per-instance check using `Entry.status`, independent of the
    ///   type-level `isInboxEligible` flag.
    /// - Entries that aren't `AssignableEntry` (currently only `DataModel.Event`) are
    ///   excluded — they use computed visibility, not assignments, and never belong in
    ///   Inbox. In practice this is already covered by `isInboxEligible` (`Event` defaults
    ///   to `false`), but the cast is kept as a defensive second check since `inboxEntries`
    ///   needs `.assignments` to evaluate matching either way.
    ///
    /// `Note.isInboxEligible == false` today (SPRD-247's already-shipped flag value), so
    /// unassigned notes are excluded here — a confirmed divergence from the legacy
    /// `StandardInboxResolver`, which includes them. See SPRD-248's plan.md notes.
    ///
    /// - Parameters:
    ///   - entries: All tasks, notes, and events in the journal.
    ///   - spreads: All existing spreads used to evaluate assignment matches.
    /// - Returns: The entries with no matching spread assignment, in their input order.
    func inboxEntries(
        entries: [any Entry],
        spreads: [DataModel.Spread]
    ) -> [any Entry] {
        entries.filter { entry in
            guard entry.isInboxEligible, entry.status != .cancelled else {
                return false
            }
            guard let assignableEntry = entry as? any AssignableEntry else {
                return false
            }
            return !isShownOnAnySpread(assignableEntry, spreads: spreads)
        }
    }

    /// Returns `true` if the entry has a current non-migrated assignment matching any spread.
    private func isShownOnAnySpread<E: AssignableEntry>(
        _ entry: E,
        spreads: [DataModel.Spread]
    ) -> Bool {
        spreads.contains { shouldShowOnSpread(entry, for: $0) }
    }

    // MARK: - Migration Planning

    /// Returns all tasks eligible to be migrated to the given destination spread.
    ///
    /// Kept concrete over `DataModel.Task` rather than generic over `AssignableEntry` —
    /// confirmed via codebase audit that `Note` is never passed through migration planning
    /// today, and `SpreadService.findBestSpread`'s task overload (`mostGranularValidDestination`)
    /// is the actual eligibility computation this relies on.
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - spreads: All existing spreads.
    ///   - destination: The target spread.
    /// - Returns: `EntryMigrationCandidate` values for each eligible task.
    func migrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        to destination: DataModel.Spread
    ) -> [EntryMigrationCandidate<DataModel.Task>] {
        tasks.compactMap { task in
            migrationCandidate(for: task, spreads: spreads, to: destination)
        }
    }

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
    /// - Returns: The most granular valid destination spread, or `nil`.
    func migrationDestination(
        for task: DataModel.Task,
        on source: DataModel.Spread,
        spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        guard task.status == .open else {
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

    /// Returns migration candidates that originate exclusively from the destination's parent hierarchy.
    ///
    /// Filters `migrationCandidates` to those whose current source spread is a direct ancestor of the
    /// destination (e.g., for a day spread, parents are month and year). Inbox-origin tasks are excluded.
    /// Results are sorted alphabetically by task title.
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - spreads: All existing spreads.
    ///   - destination: The target spread.
    /// - Returns: Sorted `EntryMigrationCandidate` values from parent spreads only.
    func parentHierarchyMigrationCandidates(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread],
        to destination: DataModel.Spread
    ) -> [EntryMigrationCandidate<DataModel.Task>] {
        let parentSpreadIDs = Set(parentHierarchySpreads(for: destination, spreads: spreads).map(\.id))

        return migrationCandidates(
            tasks: tasks,
            spreads: spreads,
            to: destination
        )
        .filter { candidate in
            guard let sourceSpread = candidate.sourceSpread else { return false }
            return parentSpreadIDs.contains(sourceSpread.id)
        }
        .sorted { lhs, rhs in
            lhs.entry.title.localizedCaseInsensitiveCompare(rhs.entry.title) == .orderedAscending
        }
    }

    /// Returns the spread where the entry has an open (`.open`) assignment.
    ///
    /// When multiple open assignments exist (which can occur transiently), the most granular spread
    /// with the most recent date is returned. An optional `excludedSpread` allows callers to filter
    /// out the spread being deleted. Generic over `AssignableEntry` since this is pure
    /// assignment-matching with no migration-specific eligibility — usable by either Task or Note.
    ///
    /// - Parameters:
    ///   - entry: The entry to inspect.
    ///   - spreads: All existing spreads.
    ///   - excludedSpread: A spread to exclude from the search, or `nil`.
    /// - Returns: The most granular spread with an open assignment, or `nil`.
    func currentDestinationSpread<E: AssignableEntry>(
        for entry: E,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        candidateSpreads(
            for: entry,
            spreads: spreads,
            excluding: excludedSpread
        ) { $0.status == .open }
    }

    /// Returns the spread where the entry is currently visible (non-migrated assignment).
    ///
    /// Similar to `currentDestinationSpread` but includes completed assignments as well
    /// as open ones. Used to show the entry's current location in migration review UIs
    /// without restricting to strictly open tasks.
    ///
    /// - Parameters:
    ///   - entry: The entry to inspect.
    ///   - spreads: All existing spreads.
    ///   - excludedSpread: A spread to exclude from the search, or `nil`.
    /// - Returns: The most granular spread with a non-migrated assignment, or `nil`.
    func currentDisplayedSpread<E: AssignableEntry>(
        for entry: E,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        candidateSpreads(
            for: entry,
            spreads: spreads,
            excluding: excludedSpread
        ) { $0.status != .migrated }
    }

    private func migrationCandidate(
        for task: DataModel.Task,
        spreads: [DataModel.Spread],
        to destination: DataModel.Spread
    ) -> EntryMigrationCandidate<DataModel.Task>? {
        guard task.status == .open, task.date != nil else {
            return nil
        }

        let sourceSpread = currentDestinationSpread(for: task, spreads: spreads, excluding: nil)
        let sourceRank = sourceSpread?.period.granularityRank ?? 0

        guard destination.period.granularityRank > sourceRank else {
            return nil
        }

        guard let bestDestination = mostGranularValidDestination(for: task, spreads: spreads) else {
            return nil
        }

        guard bestDestination.id == destination.id else {
            return nil
        }

        return EntryMigrationCandidate(
            entry: task,
            sourceSpread: sourceSpread,
            destination: destination
        )
    }

    private func candidateSpreads<E: AssignableEntry>(
        for entry: E,
        spreads: [DataModel.Spread],
        excluding excludedSpread: DataModel.Spread?,
        matching statusPredicate: (Assignment) -> Bool
    ) -> DataModel.Spread? {
        entry.assignments
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
        guard task.date != nil else { return nil }
        return spreadService.findBestSpread(for: task, in: spreads)
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

    // MARK: - Overdue Evaluation

    /// Returns all open tasks that are currently overdue.
    ///
    /// A task is overdue when its due date — determined by either its current open spread
    /// assignment or its preferred date — has fully passed relative to `today`.
    ///
    /// Overdue thresholds by period:
    /// - **Day**: The task's day has already ended (yesterday or earlier).
    /// - **Month**: The full calendar month has passed (first day of next month ≤ today).
    /// - **Year**: The full calendar year has passed (first day of next year ≤ today).
    /// - **Multiday**: Never considered overdue.
    ///
    /// Kept concrete over `DataModel.Task` — confirmed via codebase audit that only
    /// `Task.isOverdueEligible == true` today (Note/Event default `false`), and the
    /// Inbox-fallback path needs `task.period`, which deliberately doesn't generalize
    /// across `AssignableEntry` (`Task.period: Period?` vs. `Note.period: Period`).
    /// Calls `self.currentDestinationSpread` directly rather than depending on a separate
    /// injected migration planner, unlike the legacy `StandardOverdueEvaluator` — this is
    /// the consolidation's actual payoff for this seam.
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - spreads: All existing spreads, used to locate a task's current open assignment.
    /// - Returns: `OverdueTaskItem` values for each overdue open task.
    func overdueTaskItems(
        tasks: [DataModel.Task],
        spreads: [DataModel.Spread]
    ) -> [OverdueTaskItem] {
        tasks.compactMap { task in
            overdueTaskItem(for: task, spreads: spreads)
        }
    }

    private func overdueTaskItem(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> OverdueTaskItem? {
        guard task.status == .open else {
            return nil
        }

        if let openSpread = currentDestinationSpread(
            for: task,
            spreads: spreads,
            excluding: nil
        ) {
            let sourceKey = TaskReviewSourceKey(
                kind: .spread(
                    id: openSpread.id,
                    period: openSpread.period,
                    date: openSpread.period.normalizeDate(openSpread.date, calendar: calendar)
                )
            )
            guard isOverdue(spread: openSpread) else {
                return nil
            }
            return OverdueTaskItem(task: task, sourceKey: sourceKey)
        }

        guard let taskDate = task.date,
              let taskPeriod = task.period,
              isOverdue(date: taskDate, period: taskPeriod) else {
            return nil
        }
        return OverdueTaskItem(task: task, sourceKey: .init(kind: .inbox))
    }

    private func isOverdue(spread: DataModel.Spread) -> Bool {
        if spread.period == .multiday {
            guard let endDate = spread.endDate else { return false }
            let todayStart = today.startOfDay(calendar: calendar)
            return todayStart > endDate.startOfDay(calendar: calendar)
        }

        return isOverdue(date: spread.date, period: spread.period)
    }

    private func isOverdue(date: Date, period: Period) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)

        switch period {
        case .day:
            let dueDay = date.startOfDay(calendar: calendar)
            return todayStart > dueDay
        case .month:
            let startOfMonth = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return false
            }
            return todayStart >= startOfNextMonth
        case .year:
            let startOfYear = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return false
            }
            return todayStart >= startOfNextYear
        case .multiday:
            return false
        }
    }

    // MARK: - Assignment Reconciliation

    /// Updates the task's assignments so that the best matching spread is the active destination.
    ///
    /// Mutates `task.assignments` in-place. Does not persist; callers must save the task afterward.
    /// Performs no repository writes, consistent with `JournalRuleEngine` being a pure rule engine.
    ///
    /// Kept as a separate overload from the `Note` version rather than a single generic
    /// method — the destination assignment's `status` is `task.status` here (preserving
    /// complete/open), but always `.active` for notes, a real domain divergence, not
    /// incidental duplication.
    ///
    /// - Parameters:
    ///   - task: The task whose assignment should be reconciled.
    ///   - spreads: The full list of existing spreads to search.
    ///   - preferredSpreadID: Explicit multiday spread identity when the user
    ///     directly selected one.
    func reconcilePreferredAssignment(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID? = nil
    ) {
        let destination = spreadService.findBestSpread(
            for: task,
            in: spreads,
            preferredSpreadID: preferredSpreadID
        )
        let destinationStatus = task.status

        if let destination {
            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: destination, calendar: calendar)
            }) {
                for index in task.assignments.indices
                where index != destinationIndex && task.assignments[index].status != .migrated {
                    task.assignments[index].status = .migrated
                }
                task.assignments[destinationIndex].status = destinationStatus
            } else {
                migrateActiveAssignmentsToHistory(task)
                task.assignments.append(
                    Assignment(
                        period: destination.period,
                        date: destination.date,
                        spreadID: destination.period == .multiday ? destination.id : nil,
                        status: destinationStatus
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(task)
        }
    }

    /// Updates the note's assignments so that the best matching spread is the active destination.
    ///
    /// Mutates `note.assignments` in-place. Does not persist; callers must save the note afterward.
    /// Performs no repository writes, consistent with `JournalRuleEngine` being a pure rule engine.
    ///
    /// - Parameters:
    ///   - note: The note whose assignment should be reconciled.
    ///   - spreads: The full list of existing spreads to search.
    ///   - preferredSpreadID: Explicit multiday spread identity when the user
    ///     directly selected one.
    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID? = nil
    ) {
        let destination = spreadService.findBestSpread(
            for: note,
            in: spreads,
            preferredSpreadID: preferredSpreadID
        )

        if let destination {
            if let destinationIndex = note.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: destination, calendar: calendar)
            }) {
                for index in note.assignments.indices
                where index != destinationIndex && note.assignments[index].status != .migrated {
                    note.assignments[index].status = .migrated
                }
                note.assignments[destinationIndex].status = .active
            } else {
                migrateActiveAssignmentsToHistory(note)
                note.assignments.append(
                    Assignment(
                        period: destination.period,
                        date: destination.date,
                        spreadID: destination.period == .multiday ? destination.id : nil,
                        status: .active
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(note)
        }
    }

    /// Marks every non-migrated assignment on the task as migrated history.
    ///
    /// Not generalized over `AssignableEntry` — mutating `entry.assignments[index].status`
    /// through a generic `let` parameter requires the compiler to know `E` is a class (Swift
    /// can't assume this from the `AssignableEntry` constraint alone), whereas `Task`/`Note`
    /// being concrete classes makes in-place mutation through a `let` parameter work directly.
    private func migrateActiveAssignmentsToHistory(_ task: DataModel.Task) {
        for index in task.assignments.indices where task.assignments[index].status != .migrated {
            task.assignments[index].status = .migrated
        }
    }

    /// Marks every non-migrated assignment on the note as migrated history.
    private func migrateActiveAssignmentsToHistory(_ note: DataModel.Note) {
        for index in note.assignments.indices where note.assignments[index].status != .migrated {
            note.assignments[index].status = .migrated
        }
    }
}
