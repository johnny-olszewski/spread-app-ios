import Foundation
import Observation

/// The eventual `JournalManager` replacement: owns the dictionary-keyed canonical store and
/// incremental indices (`EntityStore`/`SpreadKeyIndex`/`EventSpreadIndex`), wired against the
/// `ChangeAware*` repositories (SPRD-245) and `JournalRuleEngine` (SPRD-248).
///
/// Exposes the same observed-state shape views currently read from `JournalManager`
/// (`spreads`/`tasks`/`notes`/`events`/`dataModel`/`dataVersion`), backed by O(1) store
/// lookups and incremental index updates instead of flat-array linear scans and from-zero
/// `JournalDataModel` rebuilds.
///
/// This is purely additive (SPRD-249): `DependencyContainer` and all views continue to use
/// the legacy `JournalManager` until SPRD-251's cutover. Only the read/observed-state surface
/// and store/index machinery live here — `JournalManager`'s full CRUD/migration orchestration
/// API stays with the future `TaskCoordinator`/`NoteCoordinator` (SPRD-255) and
/// `SpreadDeletionCoordinator` (SPRD-256); this type's mutation primitives
/// (`upsertTask`/`removeTask`/etc.) exist only to prove the incremental indexing design,
/// not to replicate `JournalManager`'s higher-level command surface.
@Observable
@MainActor
final class JournalDataStore {
    private let calendar: Calendar
    private let ruleEngine: JournalRuleEngine

    private let taskRepository: any ChangeAwareTaskRepository
    private let noteRepository: any ChangeAwareNoteRepository
    private let spreadRepository: any SpreadRepository
    private let eventRepository: any EventRepository

    private var taskStore = EntityStore<DataModel.Task>(idKeyPath: \.id)
    private var noteStore = EntityStore<DataModel.Note>(idKeyPath: \.id)
    private var eventStore = EntityStore<DataModel.Event>(idKeyPath: \.id)
    private var spreadStore = EntityStore<DataModel.Spread>(idKeyPath: \.id)

    private var taskIndex = SpreadKeyIndex()
    private var noteIndex = SpreadKeyIndex()
    private var eventIndex: EventSpreadIndex
    private var spreadIDByKey: [SpreadDataModelKey: UUID] = [:]
    private var keyBySpreadID: [UUID: SpreadDataModelKey] = [:]

    /// Incremented once per call to `load()`. Exists to let tests prove cold load performs
    /// exactly one full index build, and that single-entity mutations never trigger another.
    private(set) var fullLoadCount = 0

    private(set) var spreads: [DataModel.Spread] = []
    private(set) var tasks: [DataModel.Task] = []
    private(set) var notes: [DataModel.Note] = []
    private(set) var events: [DataModel.Event] = []
    private(set) var dataModel: JournalDataModel = [:]
    private(set) var dataVersion = 0

    init(
        calendar: Calendar,
        today: Date = .now,
        taskRepository: any ChangeAwareTaskRepository,
        noteRepository: any ChangeAwareNoteRepository,
        spreadRepository: any SpreadRepository,
        eventRepository: any EventRepository
    ) {
        self.calendar = calendar
        self.ruleEngine = JournalRuleEngine(calendar: calendar, today: today)
        self.taskRepository = taskRepository
        self.noteRepository = noteRepository
        self.spreadRepository = spreadRepository
        self.eventRepository = eventRepository
        self.eventIndex = EventSpreadIndex(calendar: calendar)
    }

    // MARK: - Cold Load

    /// Loads all entities from the repositories and builds the canonical store, both
    /// indices, and `dataModel` from scratch.
    ///
    /// The only place a full index build happens — every later mutation (`upsertTask`,
    /// etc.) updates only the entities/keys it touches, per the spec decision eliminating
    /// the `.structural` vs `.spreadKeys` distinction.
    func load() async {
        let loadedSpreads = await spreadRepository.getSpreads()
        let loadedTasks = await taskRepository.getTasks()
        let loadedNotes = await noteRepository.getNotes()
        let loadedEvents = await eventRepository.getEvents()

        spreadStore.replaceAll(loadedSpreads)
        taskStore.replaceAll(loadedTasks)
        noteStore.replaceAll(loadedNotes)
        eventStore.replaceAll(loadedEvents)

        spreadIDByKey = Dictionary(
            uniqueKeysWithValues: loadedSpreads.map { (SpreadDataModelKey(spread: $0, calendar: calendar), $0.id) }
        )
        keyBySpreadID = Dictionary(
            uniqueKeysWithValues: loadedSpreads.map { ($0.id, SpreadDataModelKey(spread: $0, calendar: calendar)) }
        )

        taskIndex = SpreadKeyIndex()
        for task in loadedTasks {
            taskIndex.update(entityID: task.id, keys: ruleEngine.spreadKeys(for: task, spreads: loadedSpreads))
        }

        noteIndex = SpreadKeyIndex()
        for note in loadedNotes {
            noteIndex.update(entityID: note.id, keys: ruleEngine.spreadKeys(for: note, spreads: loadedSpreads))
        }

        eventIndex = EventSpreadIndex(calendar: calendar)
        for event in loadedEvents {
            eventIndex.updateEvent(event, spreads: loadedSpreads)
        }

        spreads = loadedSpreads
        tasks = loadedTasks
        notes = loadedNotes
        events = loadedEvents

        var newDataModel: JournalDataModel = [:]
        for spread in loadedSpreads {
            let key = SpreadDataModelKey(spread: spread, calendar: calendar)
            newDataModel[key: key] = resolveSpreadDataModel(for: spread, key: key)
        }
        dataModel = newDataModel

        fullLoadCount += 1
        dataVersion += 1
    }

    // MARK: - Spread Data Model Resolution

    /// Resolves one spread's `SpreadDataModel` by reading the indices' entity-ID buckets for
    /// `key` and dereferencing only those IDs from the canonical stores.
    ///
    /// Costs O(entities indexed under `key`) — no `filter`/linear scan over the full
    /// task/note/event collections, unlike the legacy `buildSpreadDataModel(for:)` this
    /// replaces.
    private func resolveSpreadDataModel(for spread: DataModel.Spread, key: SpreadDataModelKey) -> SpreadDataModel {
        SpreadDataModel(
            spread: spread,
            tasks: taskIndex.entityIDs(for: key).compactMap { taskStore[$0] },
            notes: noteIndex.entityIDs(for: key).compactMap { noteStore[$0] },
            events: eventIndex.entityIDs(for: key).compactMap { eventStore[$0] }
        )
    }

    /// Re-resolves `dataModel[key]` from the current index/store state, or clears the entry
    /// if the spread backing `key` no longer exists.
    private func repatchDataModel(for key: SpreadDataModelKey) {
        guard let spreadID = spreadIDByKey[key], let spread = spreadStore[spreadID] else {
            dataModel[key: key] = nil
            return
        }
        dataModel[key: key] = resolveSpreadDataModel(for: spread, key: key)
    }

    // MARK: - Mutation Primitives

    /// These exist only to prove the incremental indexing design (each one updates only the
    /// store/index entries its own change touches, never triggering `load()`'s full rebuild)
    /// — not to replicate `JournalManager`'s higher-level create/update/migrate command
    /// surface, which stays with the future `TaskCoordinator`/`NoteCoordinator`/
    /// `SpreadDeletionCoordinator`. Callers are responsible for persisting via the
    /// repositories themselves; these methods only update in-memory state.

    /// Inserts a new task or updates an existing one, patching only the spread-data-model
    /// keys its assignments touch (the union of its keys before and after the change).
    func upsertTask(_ task: DataModel.Task) {
        let oldKeys = taskIndex.keys(for: task.id)
        taskStore.upsert(task)
        let newKeys = ruleEngine.spreadKeys(for: task, spreads: spreads)
        taskIndex.update(entityID: task.id, keys: newKeys)
        tasks = taskStore.values
        for key in oldKeys.union(newKeys) {
            repatchDataModel(for: key)
        }
        dataVersion += 1
    }

    /// Removes a task, patching only the spread-data-model keys it was indexed under.
    func removeTask(id: UUID) {
        let oldKeys = taskIndex.keys(for: id)
        taskStore.remove(id: id)
        taskIndex.remove(entityID: id)
        tasks = taskStore.values
        for key in oldKeys {
            repatchDataModel(for: key)
        }
        dataVersion += 1
    }

    /// Inserts a new note or updates an existing one, patching only the spread-data-model
    /// keys its assignments touch (the union of its keys before and after the change).
    func upsertNote(_ note: DataModel.Note) {
        let oldKeys = noteIndex.keys(for: note.id)
        noteStore.upsert(note)
        let newKeys = ruleEngine.spreadKeys(for: note, spreads: spreads)
        noteIndex.update(entityID: note.id, keys: newKeys)
        notes = noteStore.values
        for key in oldKeys.union(newKeys) {
            repatchDataModel(for: key)
        }
        dataVersion += 1
    }

    /// Removes a note, patching only the spread-data-model keys it was indexed under.
    func removeNote(id: UUID) {
        let oldKeys = noteIndex.keys(for: id)
        noteStore.remove(id: id)
        noteIndex.remove(entityID: id)
        notes = noteStore.values
        for key in oldKeys {
            repatchDataModel(for: key)
        }
        dataVersion += 1
    }

    /// Inserts a new event or updates an existing one. Unlike tasks/notes, an event's keys
    /// are recomputed against every current spread (`EventSpreadIndex.updateEvent`) since
    /// event visibility is computed, not assignment-based.
    func upsertEvent(_ event: DataModel.Event) {
        let oldKeys = eventIndex.keys(for: event.id)
        eventStore.upsert(event)
        eventIndex.updateEvent(event, spreads: spreads)
        let newKeys = eventIndex.keys(for: event.id)
        events = eventStore.values
        for key in oldKeys.union(newKeys) {
            repatchDataModel(for: key)
        }
        dataVersion += 1
    }

    /// Removes an event, patching only the spread-data-model keys it was visible on.
    func removeEvent(id: UUID) {
        let oldKeys = eventIndex.keys(for: id)
        eventStore.remove(id: id)
        eventIndex.removeEvent(id: id)
        events = eventStore.values
        for key in oldKeys {
            repatchDataModel(for: key)
        }
        dataVersion += 1
    }

    /// Inserts a new spread or updates an existing one (e.g. a multiday date-range edit).
    ///
    /// Only the event index needs a spread-side recompute: a task/note's index key is
    /// derived purely from its own assignment's `period`/`date` (already equal to the
    /// destination spread's own `period`/`date` at the time the assignment was created),
    /// so it's invariant to whether the spread object itself currently exists — creating or
    /// deleting a spread never changes which key an existing task/note assignment maps to.
    /// Events have no assignment to read a key from, so their membership is recomputed
    /// against the one spread that changed.
    ///
    /// The previous key is read from `keyBySpreadID` rather than re-derived from the
    /// currently-stored spread object: `DataModel.Spread` is a class, and callers mutate it
    /// in place before calling this (the established pattern elsewhere in this codebase),
    /// so by the time this runs, `spreadStore[spread.id]` would already reflect the *new*
    /// state — re-deriving the "previous" key from it would silently no-op the diff.
    func upsertSpread(_ spread: DataModel.Spread) {
        let newKey = SpreadDataModelKey(spread: spread, calendar: calendar)
        let previousKey = keyBySpreadID[spread.id]

        if let previousKey, previousKey != newKey {
            spreadIDByKey[previousKey] = nil
            eventIndex.removeSpread(key: previousKey)
            dataModel[key: previousKey] = nil
        }

        spreadStore.upsert(spread)
        spreadIDByKey[newKey] = spread.id
        keyBySpreadID[spread.id] = newKey
        spreads = spreadStore.values
        eventIndex.addSpread(spread, events: events)
        repatchDataModel(for: newKey)
        dataVersion += 1
    }

    /// Removes a spread, dropping its `dataModel` entry and its event-index bucket.
    func removeSpread(id: UUID) {
        guard let spread = spreadStore[id] else { return }
        let key = SpreadDataModelKey(spread: spread, calendar: calendar)
        spreadStore.remove(id: id)
        spreadIDByKey[key] = nil
        keyBySpreadID[id] = nil
        spreads = spreadStore.values
        eventIndex.removeSpread(spread)
        dataModel[key: key] = nil
        dataVersion += 1
    }
}
