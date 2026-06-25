import Foundation

/// A bidirectional `SpreadDataModelKey ⇄ event ID` index for event visibility.
///
/// Events are computed (date-range overlap against whatever spreads currently exist), not
/// assignment-based like tasks/notes — there's no discrete key to read directly off an
/// event the way `JournalRuleEngine.spreadKeys` reads one off a task/note's assignments.
/// Instead, this index recomputes membership on the *one* entity that changed:
/// - When an event is added/updated, `updateEvent` recomputes that one event's full key set
///   against every current spread — O(spreads), not O(events × spreads).
/// - When a spread is added/removed, `addSpread`/`removeSpread` recompute that one spread's
///   membership against every current event — O(events), not O(events × spreads).
///
/// Either direction costs more than `SpreadKeyIndex`'s O(1) entity update, but only at
/// mutation time — reads (`entityIDs(for:)`) stay O(1) bucket access, which is what the
/// O(1)-read requirement actually needs. Spreads/events are mutated far less often than
/// `SpreadDataModel` is read.
struct EventSpreadIndex {
    private var index = SpreadKeyIndex()
    private let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    private var spreadService: SpreadService {
        SpreadService(calendar: calendar)
    }

    /// All event IDs currently visible on the spread identified by `key`. O(1) bucket access.
    func entityIDs(for key: SpreadDataModelKey) -> Set<UUID> {
        index.entityIDs(for: key)
    }

    /// All spread keys the given event is currently visible on.
    func keys(for eventID: UUID) -> Set<SpreadDataModelKey> {
        index.keys(for: eventID)
    }

    /// Recomputes one event's full set of matching spread keys against every current
    /// spread. Use for event add/update, and for cold load (called once per event).
    mutating func updateEvent(_ event: DataModel.Event, spreads: [DataModel.Spread]) {
        let matchingKeys = Set(
            spreads
                .filter { spreadService.eventAppearsOnSpread(event, spread: $0) }
                .map { SpreadDataModelKey(spread: $0, calendar: calendar) }
        )
        index.update(entityID: event.id, keys: matchingKeys)
    }

    /// Removes an event from every spread it was visible on.
    mutating func removeEvent(id: UUID) {
        index.remove(entityID: id)
    }

    /// Checks the one newly added spread against every current event, adding this spread's
    /// key to each event that overlaps it. Touches only the events that actually match this
    /// spread, not the full index.
    mutating func addSpread(_ spread: DataModel.Spread, events: [DataModel.Event]) {
        let key = SpreadDataModelKey(spread: spread, calendar: calendar)
        for event in events where spreadService.eventAppearsOnSpread(event, spread: spread) {
            index.addKey(key, toEntityID: event.id)
        }
    }

    /// Removes a deleted spread's key from every event currently indexed under it.
    mutating func removeSpread(_ spread: DataModel.Spread) {
        removeSpread(key: SpreadDataModelKey(spread: spread, calendar: calendar))
    }

    /// Removes a spread's key from every event currently indexed under it, given the key
    /// directly rather than a spread instance.
    ///
    /// Needed when the caller can no longer reconstruct the *previous* key from the spread
    /// object itself — `DataModel.Spread` is a class, so once a caller mutates a spread's
    /// date range in place (the established in-place-mutation pattern this codebase uses
    /// elsewhere), the canonical store already holds the post-mutation instance by the time
    /// `JournalDataStore.upsertSpread` runs, making the pre-mutation key unrecoverable from
    /// the object alone.
    mutating func removeSpread(key: SpreadDataModelKey) {
        index.removeAllEntities(forKey: key)
    }
}
