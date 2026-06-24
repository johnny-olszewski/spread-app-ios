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
}
