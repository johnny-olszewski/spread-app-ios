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
}
