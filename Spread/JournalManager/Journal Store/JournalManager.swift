import Foundation
import Observation
import OSLog

/// Central coordinator for journal data and operations.
///
/// Owns the dictionary-keyed canonical store and incremental indices
/// (`EntityStore`/`SpreadKeyIndex`/`EventSpreadIndex`), wired against the `TaskRepository`/
/// `NoteRepository` repositories (SPRD-245) and `JournalRuleEngine` (SPRD-248). Exposes the
/// observed-state shape and command surface views read directly — O(1) store lookups and
/// incremental index updates instead of flat-array linear scans and from-zero
/// `JournalDataModel` rebuilds.
///
/// Replaces the original `JournalManager` implementation as of SPRD-251's cutover — the type
/// name is unchanged for views; only the internals (and this doc comment) changed.
@Observable
@MainActor
final class JournalManager {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "JournalManager")

    private var ruleEngine: JournalRuleEngine
    private(set) var calendar: Calendar
    private(set) var today: Date

    let appClock: AppClock
    private var appClockObserverID: UUID?

    let taskRepository: any TaskRepository
    let noteRepository: any NoteRepository
    let spreadRepository: any SpreadRepository
    let eventRepository: any EventRepository
    let collectionRepository: (any CollectionRepository)?
    let listRepository: any ListRepository
    let tagRepository: any TagRepository

    var firstWeekday: FirstWeekday
    var creationPolicy: SpreadCreationPolicy

    /// The calendar adjusted for the user's first-day-of-week preference.
    var configuredCalendar: Calendar {
        firstWeekday.configuredCalendar(from: calendar)
    }

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
    private(set) var lists: [DataModel.List] = []
    private(set) var tags: [DataModel.Tag] = []
    private(set) var dataModel: JournalDataModel = [:]
    private(set) var dataVersion = 0

    init(
        appClock: AppClock,
        taskRepository: any TaskRepository,
        noteRepository: any NoteRepository,
        spreadRepository: any SpreadRepository,
        eventRepository: any EventRepository,
        collectionRepository: (any CollectionRepository)? = nil,
        listRepository: (any ListRepository)? = nil,
        tagRepository: (any TagRepository)? = nil,
        firstWeekday: FirstWeekday = .systemDefault,
        creationPolicy: SpreadCreationPolicy
    ) {
        self.appClock = appClock
        self.calendar = appClock.calendar
        self.today = appClock.now
        self.ruleEngine = JournalRuleEngine(calendar: appClock.calendar, today: appClock.now)
        self.taskRepository = taskRepository
        self.noteRepository = noteRepository
        self.spreadRepository = spreadRepository
        self.eventRepository = eventRepository
        self.collectionRepository = collectionRepository
        self.listRepository = listRepository ?? EmptyListRepository()
        self.tagRepository = tagRepository ?? EmptyTagRepository()
        self.firstWeekday = firstWeekday
        self.creationPolicy = creationPolicy
        self.eventIndex = EventSpreadIndex(calendar: appClock.calendar)
        wireAppClock()
    }

    /// Creates a `JournalManager` for testing with in-memory repositories, paralleling the
    /// legacy `JournalManager.make`.
    convenience init(
        appClock: AppClock? = nil,
        calendar: Calendar? = nil,
        today: Date? = nil,
        taskRepository: (any TaskRepository)? = nil,
        spreadRepository: (any SpreadRepository)? = nil,
        eventRepository: (any EventRepository)? = nil,
        noteRepository: (any NoteRepository)? = nil,
        collectionRepository: (any CollectionRepository)? = nil,
        listRepository: (any ListRepository)? = nil,
        tagRepository: (any TagRepository)? = nil,
        firstWeekday: FirstWeekday = .systemDefault,
        creationPolicy: SpreadCreationPolicy? = nil
    ) async {
        var testCalendar: Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .init(identifier: "UTC")!
            return cal
        }

        let resolvedCalendar = calendar ?? testCalendar
        let resolvedToday = today ?? .now
        let defaultPolicy = StandardCreationPolicy(today: resolvedToday, firstWeekday: firstWeekday)
        let resolvedClock = appClock ?? AppClock.fixed(
            now: resolvedToday,
            calendar: resolvedCalendar,
            timeZone: resolvedCalendar.timeZone,
            locale: resolvedCalendar.locale ?? Locale(identifier: "en_US_POSIX")
        )

        self.init(
            appClock: resolvedClock,
            taskRepository: taskRepository ?? TestTaskRepository(),
            noteRepository: noteRepository ?? TestNoteRepository(),
            spreadRepository: spreadRepository ?? TestSpreadRepository(),
            eventRepository: eventRepository ?? TestEventRepository(),
            collectionRepository: collectionRepository,
            listRepository: listRepository,
            tagRepository: tagRepository,
            firstWeekday: firstWeekday,
            creationPolicy: creationPolicy ?? defaultPolicy
        )
        await load()
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
        let loadedLists = await listRepository.getLists()
        let loadedTags = await tagRepository.getTags()

        rebuildIndicesAndDataModel(
            spreads: loadedSpreads,
            tasks: loadedTasks,
            notes: loadedNotes,
            events: loadedEvents,
            lists: loadedLists,
            tags: loadedTags
        )

        fullLoadCount += 1
    }

    /// Rebuilds every store/index/`dataModel` entry from the given entity arrays.
    ///
    /// Shared by `load()` (using freshly-fetched repository data) and `apply(snapshot:)`
    /// (using the entities already in memory, just re-keyed against a new calendar/today
    /// after a day-boundary/calendar/time-zone/locale change) — neither path does a
    /// redundant repository round trip the other doesn't need.
    private func rebuildIndicesAndDataModel(
        spreads loadedSpreads: [DataModel.Spread],
        tasks loadedTasks: [DataModel.Task],
        notes loadedNotes: [DataModel.Note],
        events loadedEvents: [DataModel.Event],
        lists loadedLists: [DataModel.List],
        tags loadedTags: [DataModel.Tag]
    ) {
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
        lists = loadedLists
        tags = loadedTags

        var newDataModel: JournalDataModel = [:]
        for spread in loadedSpreads {
            let key = SpreadDataModelKey(spread: spread, calendar: calendar)
            newDataModel[key: key] = resolveSpreadDataModel(for: spread, key: key)
        }
        dataModel = newDataModel
    }

    /// Reloads data from repositories. Increments `dataVersion` to trigger UI updates.
    ///
    /// `load()` itself does not bump `dataVersion` — it's used for the initial cold load,
    /// before any view has observed state yet. `reload()` is the explicit "refresh and notify"
    /// path used after initial load (e.g. sign-out wipe, debug data reset).
    func reload() async {
        await load()
        dataVersion += 1
    }

    /// Returns true if any local data exists in repositories.
    func hasLocalData() async -> Bool {
        if !(await spreadRepository.getSpreads()).isEmpty { return true }
        if !(await taskRepository.getTasks()).isEmpty { return true }
        if !(await eventRepository.getEvents()).isEmpty { return true }
        if !(await noteRepository.getNotes()).isEmpty { return true }
        return false
    }

    /// Clears all local data from repositories and refreshes in-memory state. Used on sign-out.
    func clearLocalData() async {
        do {
            try await clearAllDataFromRepositories()
        } catch {
            // Best-effort wipe; keep going to refresh UI state.
        }
        await reload()
    }

    /// Clears all data from repositories (without updating in-memory state). Helper for
    /// sign-out and debug data resets.
    func clearAllDataFromRepositories() async throws {
        for task in await taskRepository.getTasks() {
            try await taskRepository.delete(task)
        }
        for spread in await spreadRepository.getSpreads() {
            try await spreadRepository.delete(spread)
        }
        for event in await eventRepository.getEvents() {
            try await eventRepository.delete(event)
        }
        for note in await noteRepository.getNotes() {
            try await noteRepository.delete(note)
        }
        if let collectionRepository {
            for collection in await collectionRepository.getCollections() {
                try await collectionRepository.delete(collection)
            }
        }
        for list in await listRepository.getLists() {
            try await listRepository.delete(list)
        }
        for tag in await tagRepository.getTags() {
            try await tagRepository.delete(tag)
        }
    }

    // MARK: - AppClock Wiring

    private func wireAppClock() {
        appClockObserverID = appClock.addObserver { [weak self] snapshot in
            self?.apply(snapshot: snapshot)
        }
    }

    private func apply(snapshot: AppClockSnapshot) {
        calendar = snapshot.calendar
        today = snapshot.now

        guard snapshot.refreshMetadata.crossedDayBoundary ||
                snapshot.refreshMetadata.calendarChanged ||
                snapshot.refreshMetadata.timeZoneChanged ||
                snapshot.refreshMetadata.localeChanged else {
            return
        }

        creationPolicy = StandardCreationPolicy(today: today, firstWeekday: firstWeekday)
        ruleEngine = JournalRuleEngine(calendar: calendar, today: today)

        // Rebuilds synchronously from data already in memory — no repository round trip
        // needed, since nothing about the underlying entities changed, only the
        // calendar/today they're being re-keyed against. Matches the legacy
        // rebuildTemporalCollaborators()/buildDataModel() behavior, which was also
        // synchronous for the same reason.
        rebuildIndicesAndDataModel(spreads: spreads, tasks: tasks, notes: notes, events: events, lists: lists, tags: tags)
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
            tasks: Self.sortedByCreatedDate(taskIndex.entityIDs(for: key).compactMap { taskStore[$0] }),
            notes: Self.sortedByCreatedDate(noteIndex.entityIDs(for: key).compactMap { noteStore[$0] }),
            events: Self.sortedByCreatedDate(eventIndex.entityIDs(for: key).compactMap { eventStore[$0] })
        )
    }

    /// `EntityStore.values`/index bucket lookups are dictionary/set-backed and have no
    /// inherent order, unlike the legacy array-based `tasks.filter { ... }` this replaces
    /// (which preserved the originating repository's order — `createdDate` ascending for
    /// tasks/notes/events, confirmed against each repository's own `getTasks`/`getNotes`/
    /// `getEvents` sort). Re-sorting here keeps that same observable order after any
    /// mutation, not just at cold load.
    private static func sortedByCreatedDate<E: Entry>(_ entries: [E]) -> [E] {
        entries.sorted { $0.createdDate < $1.createdDate }
    }

    /// Mirrors `TestSpreadRepository`/`SwiftDataSpreadRepository`'s spread ordering
    /// (period rank ascending, then date descending) so `spreads` stays in the same order
    /// after a mutation as it was at cold load.
    private static func sortedSpreads(_ spreads: [DataModel.Spread]) -> [DataModel.Spread] {
        spreads.sorted { lhs, rhs in
            if lhs.period != rhs.period {
                return spreadPeriodSortOrder(lhs.period) < spreadPeriodSortOrder(rhs.period)
            }
            return lhs.date > rhs.date
        }
    }

    private static func spreadPeriodSortOrder(_ period: Period) -> Int {
        switch period {
        case .year: 0
        case .month: 1
        case .day: 2
        case .multiday: 3
        }
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

    func spreadDataModel(for date: Date, period: Period) -> SpreadDataModel? {
        dataModel[key: SpreadDataModelKey(period: period, date: date, calendar: calendar)]
    }

    // MARK: - Inbox

    /// All entries across the three concrete `Entry` types, regardless of inbox eligibility.
    var allEntries: [any Entry] {
        tasks + events + notes
    }

    /// Entries that have no matching spread assignment. See `JournalRuleEngine.inboxEntries`
    /// for the eligibility rule (gated by `Entry.isInboxEligible`, which currently excludes
    /// events and notes). `allEntries` is passed here rather than `tasks` alone so the rule
    /// engine remains the single source of truth for eligibility as more entry types arrive.
    var inboxEntries: [any Entry] {
        ruleEngine.inboxEntries(entries: allEntries, spreads: spreads)
    }

    /// The number of entries in the Inbox. Used for badge display.
    var inboxCount: Int {
        inboxEntries.count
    }

    // MARK: - Migration Queries

    /// Tasks eligible to move into created spreads in conventional mode.
    func migrationCandidates(to destination: DataModel.Spread) -> [EntryMigrationCandidate<DataModel.Task>] {
        ruleEngine.migrationCandidates(tasks: tasks, spreads: spreads, to: destination)
    }

    /// Returns the smallest valid existing destination spread for a task on a specific source spread.
    func migrationDestination(for task: DataModel.Task, on source: DataModel.Spread) -> DataModel.Spread? {
        ruleEngine.migrationDestination(for: task, on: source, spreads: spreads)
    }

    /// Returns migration candidates that come only from the destination's parent hierarchy.
    func parentHierarchyMigrationCandidates(to destination: DataModel.Spread) -> [EntryMigrationCandidate<DataModel.Task>] {
        ruleEngine.parentHierarchyMigrationCandidates(tasks: tasks, spreads: spreads, to: destination)
    }

    /// Returns all tasks eligible for migration from `source` to `destination` (open status, matching source assignment).
    func eligibleTasksForMigration(from source: DataModel.Spread, to destination: DataModel.Spread) -> [DataModel.Task] {
        guard destination.period.canHaveTasksAssigned else { return [] }
        return tasks.filter { task in
            guard task.status != .cancelled else { return false }
            guard let sourceAssignment = task.currentAssignments.first(where: { $0.matches(spread: source, calendar: calendar) }) else {
                return false
            }
            return sourceAssignment.status == .open
        }
    }

    /// Returns all tasks eligible for migration from any parent spread to the given destination.
    func allEligibleTasksForMigration(to destination: DataModel.Spread) -> [(task: DataModel.Task, source: DataModel.Spread)] {
        migrationCandidates(to: destination).compactMap { candidate in
            guard let sourceSpread = candidate.sourceSpread else { return nil }
            return (task: candidate.entry, source: sourceSpread)
        }
    }

    /// Returns the spread where the task has an open assignment, if any.
    func currentDestinationSpread(for task: DataModel.Task, excluding excludedSpread: DataModel.Spread? = nil) -> DataModel.Spread? {
        ruleEngine.currentDestinationSpread(for: task, spreads: spreads, excluding: excludedSpread)
    }

    /// Returns the spread where the task is currently visible to the user (any non-migrated assignment).
    func currentDisplayedSpread(for task: DataModel.Task, excluding excludedSpread: DataModel.Spread? = nil) -> DataModel.Spread? {
        ruleEngine.currentDisplayedSpread(for: task, spreads: spreads, excluding: excludedSpread)
    }

    // MARK: - Overdue

    /// Open tasks that are overdue anywhere in the journal.
    var overdueTaskItems: [OverdueTaskItem] {
        ruleEngine.overdueTaskItems(tasks: tasks, spreads: spreads)
    }

    /// The global overdue count used by the toolbar review button.
    var overdueTaskCount: Int {
        overdueTaskItems.count
    }

    // MARK: - Spread Management

    /// Creates a new explicit spread and returns any auto-migration summary produced by the
    /// conventional year/month/day reconciliation pass.
    func createSpread(
        period: Period,
        date: Date,
        customName: String? = nil,
        usesDynamicName: Bool = true
    ) async throws -> SpreadCreationOperationResult {
        let spread = DataModel.Spread(
            period: period,
            date: date,
            calendar: calendar,
            customName: SpreadDisplayNameFormatter.sanitizedCustomName(customName),
            usesDynamicName: usesDynamicName
        )
        try await spreadRepository.save(spread)
        upsertSpread(spread)

        let autoMigrationSummary = try await reconcileEntriesForNewExplicitSpreadIfNeeded(spread)
        return SpreadCreationOperationResult(spread: spread, autoMigrationSummary: autoMigrationSummary)
    }

    /// Creates a new spread (convenience wrapper discarding the auto-migration summary).
    @discardableResult
    func addSpread(period: Period, date: Date, customName: String? = nil, usesDynamicName: Bool = true) async throws -> DataModel.Spread {
        try await createSpread(period: period, date: date, customName: customName, usesDynamicName: usesDynamicName).spread
    }

    /// Creates a new multiday spread, also reconciling eligible day-preferred and
    /// multiday-preferred entries into it when it becomes their best available destination.
    func addMultidaySpread(startDate: Date, endDate: Date, customName: String? = nil, usesDynamicName: Bool = true) async throws -> DataModel.Spread {
        let spread = DataModel.Spread(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar,
            customName: SpreadDisplayNameFormatter.sanitizedCustomName(customName),
            usesDynamicName: usesDynamicName
        )
        try await spreadRepository.save(spread)
        upsertSpread(spread)
        _ = try await reconcileEntriesForNewExplicitSpreadIfNeeded(spread)
        return spread
    }

    /// Updates the explicit-spread favorite flag and field-level sync timestamp.
    func updateSpreadFavorite(_ spread: DataModel.Spread, isFavorite: Bool) async throws {
        guard spread.isFavorite != isFavorite else { return }
        spread.isFavorite = isFavorite
        spread.isFavoriteUpdatedAt = .now
        try await spreadRepository.save(spread)
        upsertSpread(spread)
    }

    /// Updates the explicit-spread custom and dynamic naming fields.
    func updateSpreadName(_ spread: DataModel.Spread, customName: String?, usesDynamicName: Bool) async throws {
        let sanitizedCustomName = SpreadDisplayNameFormatter.sanitizedCustomName(customName)
        let timestamp = Date.now
        var didChange = false

        if spread.customName != sanitizedCustomName {
            spread.customName = sanitizedCustomName
            spread.customNameUpdatedAt = timestamp
            didChange = true
        }
        if spread.usesDynamicName != usesDynamicName {
            spread.usesDynamicName = usesDynamicName
            spread.usesDynamicNameUpdatedAt = timestamp
            didChange = true
        }
        guard didChange else { return }

        try await spreadRepository.save(spread)
        upsertSpread(spread)
    }

    /// Updates an explicit multiday spread's date range while preserving its identity and personalization.
    @discardableResult
    func updateMultidaySpreadDates(_ spread: DataModel.Spread, startDate: Date, endDate: Date) async throws -> DataModel.Spread {
        guard spread.period == .multiday else { return spread }

        let normalizedStart = startDate.startOfDay(calendar: calendar)
        let normalizedEnd = endDate.startOfDay(calendar: calendar)
        guard spread.date != normalizedStart || spread.startDate != normalizedStart || spread.endDate != normalizedEnd else {
            return spread
        }

        let timestamp = Date.now
        spread.date = normalizedStart
        spread.startDate = normalizedStart
        spread.endDate = normalizedEnd
        spread.dateUpdatedAt = timestamp
        spread.startDateUpdatedAt = timestamp
        spread.endDateUpdatedAt = timestamp

        try await spreadRepository.save(spread)
        upsertSpread(spread)
        return spread
    }

    /// Deletes a spread, reassigning all of its entries to a parent spread (day→month→year) or
    /// Inbox if none exists. Entries are never deleted, only their assignments are mutated.
    ///
    /// Scoped to non-multiday deletion's parent-hierarchy walk — multiday-spread deletion falls
    /// straight to Inbox for its entries (no parent-hierarchy concept applies to a custom range).
    func deleteSpread(_ spread: DataModel.Spread) async throws {
        let parentSpread = spread.period == .multiday ? nil : findParentSpread(for: spread, in: spreads)

        for task in tasks {
            let previousTaskAssignments = task.currentAssignments + task.migrationHistory

            let sourceAssignment: Assignment
            if let currentIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = task.currentAssignments.remove(at: currentIndex)
            } else if let historyIndex = task.migrationHistory.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = task.migrationHistory.remove(at: historyIndex)
            } else {
                continue
            }
            let preservedStatus = sourceAssignment.status

            // The source assignment always ends up migrated history, whether or not a
            // replacement is found — deleting its spread invalidates it as a current
            // pointer either way.
            var sourceAsHistory = sourceAssignment
            sourceAsHistory.status = .migrated
            task.migrationHistory.append(sourceAsHistory)

            if let replacement = replacementSpread(for: task, deleting: spread, parentSpread: parentSpread) {
                if let destinationIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    task.currentAssignments[destinationIndex].status = preservedStatus
                } else if let historyIndex = task.migrationHistory.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    if preservedStatus == .migrated {
                        task.migrationHistory[historyIndex].status = preservedStatus
                    } else {
                        var revived = task.migrationHistory.remove(at: historyIndex)
                        revived.status = preservedStatus
                        task.currentAssignments.append(revived)
                    }
                } else {
                    let newAssignment = Assignment(period: replacement.period, date: replacement.date, status: preservedStatus)
                    if preservedStatus == .migrated {
                        task.migrationHistory.append(newAssignment)
                    } else {
                        task.currentAssignments.append(newAssignment)
                    }
                }
            }

            try await taskRepository.save(
                task,
                change: EntityChange(isNew: false, previousAssignments: previousTaskAssignments, previousTagIDs: task.tags.map(\.id))
            )
            upsertTask(task)
        }

        for note in notes {
            let previousNoteAssignments = note.currentAssignments + note.migrationHistory

            let sourceAssignment: Assignment
            if let currentIndex = note.currentAssignments.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = note.currentAssignments.remove(at: currentIndex)
            } else if let historyIndex = note.migrationHistory.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = note.migrationHistory.remove(at: historyIndex)
            } else {
                continue
            }
            let preservedStatus = sourceAssignment.status

            // The source assignment always ends up migrated history, whether or not a
            // replacement is found — deleting its spread invalidates it as a current
            // pointer either way.
            var sourceAsHistory = sourceAssignment
            sourceAsHistory.status = .migrated
            note.migrationHistory.append(sourceAsHistory)

            if let replacement = replacementSpread(for: note, deleting: spread, parentSpread: parentSpread) {
                if let destinationIndex = note.currentAssignments.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    note.currentAssignments[destinationIndex].status = preservedStatus
                } else if let historyIndex = note.migrationHistory.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    if preservedStatus == .migrated {
                        note.migrationHistory[historyIndex].status = preservedStatus
                    } else {
                        var revived = note.migrationHistory.remove(at: historyIndex)
                        revived.status = preservedStatus
                        note.currentAssignments.append(revived)
                    }
                } else {
                    let newAssignment = Assignment(period: replacement.period, date: replacement.date, status: preservedStatus)
                    if preservedStatus == .migrated {
                        note.migrationHistory.append(newAssignment)
                    } else {
                        note.currentAssignments.append(newAssignment)
                    }
                }
            }

            try await noteRepository.save(
                note,
                change: EntityChange(isNew: false, previousAssignments: previousNoteAssignments, previousTagIDs: note.tags.map(\.id))
            )
            upsertNote(note)
        }

        try await spreadRepository.delete(spread)
        removeSpread(id: spread.id)

        Self.logger.debug("Spread deleted: \(spread.period.rawValue, privacy: .public) spread \(spread.id, privacy: .public)")
    }

    /// Mirrors the legacy `StandardSpreadDeletionPlanner.replacementSpread`: for a
    /// non-multiday deletion, the replacement is simply the parent spread already found by
    /// `findParentSpread`. For a multiday deletion, there's no parent-hierarchy concept for
    /// a custom range — instead, fall back to whatever non-multiday spread best matches the
    /// task's own preferred date/period (excluding the spread being deleted), the same way
    /// the legacy planner did.
    private func replacementSpread(
        for task: DataModel.Task,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?
    ) -> DataModel.Spread? {
        guard spread.period == .multiday else { return parentSpread }
        guard let taskDate = task.date else { return nil }
        let fallbackPeriod: Period = task.period == .multiday ? .month : (task.period ?? .day)
        return SpreadService(calendar: calendar).findBestSpread(
            preferredDate: taskDate,
            preferredPeriod: fallbackPeriod,
            in: spreads.filter { $0.id != spread.id && $0.period != .multiday }
        )
    }

    /// Mirrors the legacy `StandardSpreadDeletionPlanner.replacementSpread` for notes.
    private func replacementSpread(
        for note: DataModel.Note,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?
    ) -> DataModel.Spread? {
        guard spread.period == .multiday else { return parentSpread }
        guard let noteDate = note.date else { return nil }
        let fallbackPeriod: Period = note.period == .multiday ? .month : note.period
        return SpreadService(calendar: calendar).findBestSpread(
            preferredDate: noteDate,
            preferredPeriod: fallbackPeriod,
            in: spreads.filter { $0.id != spread.id && $0.period != .multiday }
        )
    }

    private func findParentSpread(for spread: DataModel.Spread, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        var currentPeriod = spread.period.parentPeriod
        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(spread.date, calendar: calendar)
            if let parent = spreads.first(where: {
                $0.period == period && $0.period.normalizeDate($0.date, calendar: calendar) == normalizedDate
            }) {
                return parent
            }
            currentPeriod = period.parentPeriod
        }
        return nil
    }

    /// Re-reconciles every existing task/note against a newly created explicit spread, in case
    /// it's now their best destination (e.g. an Inbox-origin task whose preferred date matches).
    private func reconcileEntriesForNewExplicitSpreadIfNeeded(_ spread: DataModel.Spread) async throws -> SpreadAutoMigrationSummary? {
        guard spread.period.canHaveTasksAssigned else { return nil }

        var migratedTaskCount = 0
        var migratedNoteCount = 0

        for task in tasks where task.date != nil && task.status != .cancelled && task.status != .migrated {
            let previousAssignments = task.currentAssignments + task.migrationHistory
            ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: nil)
            guard task.currentAssignments + task.migrationHistory != previousAssignments else { continue }
            try await taskRepository.save(task, change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id)))
            upsertTask(task)
            migratedTaskCount += 1
        }

        for note in notes where note.status != .migrated {
            let previousAssignments = note.currentAssignments + note.migrationHistory
            ruleEngine.reconcilePreferredAssignment(for: note, in: spreads, preferredSpreadID: nil)
            guard note.currentAssignments + note.migrationHistory != previousAssignments else { continue }
            try await noteRepository.save(note, change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: note.tags.map(\.id)))
            upsertNote(note)
            migratedNoteCount += 1
        }

        guard migratedTaskCount > 0 || migratedNoteCount > 0 else { return nil }
        return SpreadAutoMigrationSummary(taskCount: migratedTaskCount, noteCount: migratedNoteCount)
    }

    // MARK: - Task Migration

    /// Migrates a task from a source spread to a destination spread.
    func migrateTask(_ task: DataModel.Task, from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        try await moveTask(task, from: .init(kind: .spread(id: source.id, period: source.period, date: source.period.normalizeDate(source.date, calendar: calendar))), to: destination)
    }

    /// Moves a task from either Inbox or a source spread into a destination spread.
    func moveTask(_ task: DataModel.Task, from sourceKey: TaskReviewSourceKey, to destination: DataModel.Spread) async throws {
        guard task.status != .cancelled else { throw MigrationError.taskCancelled }
        guard destination.period.canHaveTasksAssigned else { throw MigrationError.destinationNotAssignable }
        let previousAssignments = task.currentAssignments + task.migrationHistory

        switch sourceKey.kind {
        case .inbox:
            break
        case .spread(let sourceSpreadID, let sourcePeriod, let sourceDate):
            guard let sourceIndex = task.currentAssignments.firstIndex(where: {
                $0.matches(period: sourcePeriod, date: sourceDate, spreadID: sourceSpreadID, calendar: calendar)
            }) else {
                throw MigrationError.noSourceAssignment
            }
            var sourceAssignment = task.currentAssignments.remove(at: sourceIndex)
            sourceAssignment.status = .migrated
            task.migrationHistory.append(sourceAssignment)
        }

        if let destinationIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
            task.currentAssignments[destinationIndex].status = .open
        } else if let historyIndex = task.migrationHistory.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
            var revived = task.migrationHistory.remove(at: historyIndex)
            revived.status = .open
            task.currentAssignments.append(revived)
        } else {
            task.currentAssignments.append(
                Assignment(period: destination.period, date: destination.date, spreadID: destination.period == .multiday ? destination.id : nil, status: .open)
            )
        }
        task.status = .open

        try await taskRepository.save(
            task,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
        )
        upsertTask(task)
    }

    /// Migrates multiple tasks from one spread to another. Skips cancelled tasks silently.
    func migrateTasksBatch(_ tasks: [DataModel.Task], from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        guard !tasks.isEmpty else { return }
        guard destination.period.canHaveTasksAssigned else { throw MigrationError.destinationNotAssignable }

        for task in tasks {
            guard task.status != .cancelled else { continue }
            guard let sourceIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: source, calendar: calendar) }) else {
                continue
            }
            let previousAssignments = task.currentAssignments + task.migrationHistory
            var sourceAssignment = task.currentAssignments.remove(at: sourceIndex)
            sourceAssignment.status = .migrated
            task.migrationHistory.append(sourceAssignment)

            if let destinationIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
                task.currentAssignments[destinationIndex].status = .open
            } else if let historyIndex = task.migrationHistory.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
                var revived = task.migrationHistory.remove(at: historyIndex)
                revived.status = .open
                task.currentAssignments.append(revived)
            } else {
                task.currentAssignments.append(
                    Assignment(period: destination.period, date: destination.date, spreadID: destination.period == .multiday ? destination.id : nil, status: .open)
                )
            }
            task.status = .open
            try await taskRepository.save(
                task,
                change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
            )
            upsertTask(task)
        }
    }

    /// Migrates a note from one spread to another. Notes can only be migrated via explicit
    /// user action, not batch migration.
    func migrateNote(_ note: DataModel.Note, from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        guard destination.period.canHaveTasksAssigned else { throw MigrationError.destinationNotAssignable }
        guard let sourceIndex = note.currentAssignments.firstIndex(where: { $0.matches(spread: source, calendar: calendar) }) else {
            throw MigrationError.noSourceAssignment
        }
        let previousAssignments = note.currentAssignments + note.migrationHistory
        var sourceAssignment = note.currentAssignments.remove(at: sourceIndex)
        sourceAssignment.status = .migrated
        note.migrationHistory.append(sourceAssignment)

        if let destinationIndex = note.currentAssignments.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
            note.currentAssignments[destinationIndex].status = .active
        } else if let historyIndex = note.migrationHistory.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
            var revived = note.migrationHistory.remove(at: historyIndex)
            revived.status = .active
            note.currentAssignments.append(revived)
        } else {
            note.currentAssignments.append(
                Assignment(period: destination.period, date: destination.date, spreadID: destination.period == .multiday ? destination.id : nil, status: .active)
            )
        }

        try await noteRepository.save(
            note,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: note.tags.map(\.id))
        )
        upsertNote(note)
    }

    /// Events cannot be migrated — they use computed visibility based on date range overlap.
    func migrateEvent(_ event: DataModel.Event, from source: DataModel.Spread, to destination: DataModel.Spread) throws {
        throw MigrationError.eventMigrationNotSupported
    }

    // MARK: - Task CRUD

    /// Creates a new task with the specified parameters.
    @discardableResult
    func addTask(title: String, date: Date, period: Period, list: DataModel.List? = nil, tag: DataModel.Tag? = nil) async throws -> DataModel.Task {
        let task = try await addTask(title: title, date: date, period: period, body: nil, priority: .none, dueDate: nil)
        guard list != nil || tag != nil else { return task }
        if let list { task.list = list }
        if let tag { task.tags = [tag] }
        try await taskRepository.save(task, change: EntityChange(isNew: false, previousAssignments: task.currentAssignments + task.migrationHistory, previousTagIDs: []))
        upsertTask(task)
        return task
    }

    /// Creates a new task with metadata and explicit preferred-assignment state.
    @discardableResult
    func addTask(
        title: String,
        date: Date?,
        period: Period?,
        preferredSpreadID: UUID? = nil,
        body: String?,
        priority: DataModel.Task.Priority,
        dueDate: Date?
    ) async throws -> DataModel.Task {
        let normalizedDate = date.map { period?.normalizeDate($0, calendar: calendar) ?? $0 }
        let task = DataModel.Task(
            title: title,
            body: sanitizedTaskBody(body),
            priority: priority,
            dueDate: dueDate?.startOfDay(calendar: calendar),
            date: normalizedDate,
            period: period,
            status: .open,
            currentAssignments: []
        )

        if normalizedDate != nil {
            ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: preferredSpreadID)
        }

        try await taskRepository.save(task, change: EntityChange(isNew: true))
        upsertTask(task)

        if task.currentAssignments.isEmpty {
            Self.logger.debug("Task created: \(task.id, privacy: .public) '\(task.title, privacy: .public)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Task created: \(task.id, privacy: .public) '\(task.title, privacy: .public)' → \(task.period?.rawValue ?? "none", privacy: .public) spread")
        }

        return task
    }

    /// Updates a task's title.
    func updateTaskTitle(_ task: DataModel.Task, newTitle: String) async throws {
        let change = EntityChange(isNew: false, previousAssignments: task.currentAssignments + task.migrationHistory, previousTagIDs: task.tags.map(\.id))
        task.title = newTitle
        try await taskRepository.save(task, change: change)
        upsertTask(task)
    }

    /// Updates a task's status (excluding `.migrated`, which is only set by migration flows).
    func updateTaskStatus(_ task: DataModel.Task, newStatus: EntryStatus) async throws {
        guard newStatus != .migrated else { throw TaskMutationError.manualMigratedStatusNotAllowed }
        let change = EntityChange(isNew: false, previousAssignments: task.currentAssignments + task.migrationHistory, previousTagIDs: task.tags.map(\.id))
        task.status = newStatus
        try await taskRepository.save(task, change: change)
        upsertTask(task)
    }

    /// Updates a task's preferred date and period, reconciling its spread assignment.
    func updateTaskDateAndPeriod(_ task: DataModel.Task, newDate: Date, newPeriod: Period, preferredSpreadID: UUID? = nil) async throws {
        let change = EntityChange(isNew: false, previousAssignments: task.currentAssignments + task.migrationHistory, previousTagIDs: task.tags.map(\.id))
        task.date = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.period = newPeriod
        ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: preferredSpreadID)
        try await taskRepository.save(task, change: change)
        upsertTask(task)
    }

    /// Updates independently mergeable task metadata.
    func updateTaskMetadata(_ task: DataModel.Task, body: String?, priority: DataModel.Task.Priority, dueDate: Date?, list: DataModel.List? = nil, tags: [DataModel.Tag] = []) async throws {
        let previousTagIDs = task.tags.map(\.id)
        let timestamp = Date.now
        let normalizedBody = sanitizedTaskBody(body)
        let normalizedDueDate = dueDate?.startOfDay(calendar: calendar)

        if task.body != normalizedBody {
            task.body = normalizedBody
            task.bodyUpdatedAt = timestamp
        }
        if task.priority != priority {
            task.priority = priority
            task.priorityUpdatedAt = timestamp
        }
        if task.dueDate != normalizedDueDate {
            task.dueDate = normalizedDueDate
            task.dueDateUpdatedAt = timestamp
        }
        if task.list?.id != list?.id {
            task.list = list
            task.listUpdatedAt = timestamp
        }
        if Set(previousTagIDs) != Set(tags.map(\.id)) {
            task.tags = tags
        }

        try await taskRepository.save(task, change: EntityChange(isNew: false, previousAssignments: task.currentAssignments + task.migrationHistory, previousTagIDs: previousTagIDs))
        upsertTask(task)
    }

    /// Clears a task's preferred assignment, leaving it in Inbox until explicitly reassigned.
    func clearTaskPreferredAssignment(_ task: DataModel.Task) async throws {
        let change = EntityChange(isNew: false, previousAssignments: task.currentAssignments + task.migrationHistory, previousTagIDs: task.tags.map(\.id))
        task.date = nil
        task.period = nil
        ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: nil)
        try await taskRepository.save(task, change: change)
        upsertTask(task)
    }

    /// Deletes a task from the repository and local state.
    func deleteTask(_ task: DataModel.Task) async throws {
        try await taskRepository.delete(task)
        removeTask(id: task.id)
    }

    private func sanitizedTaskBody(_ body: String?) -> String? {
        guard let trimmed = body?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    // MARK: - Note CRUD

    /// Creates a new note.
    @discardableResult
    func addNote(title: String, content: String = "", date: Date, period: Period, preferredSpreadID: UUID? = nil) async throws -> DataModel.Note {
        let note = DataModel.Note(
            title: title,
            content: content,
            date: period.normalizeDate(date, calendar: calendar),
            period: period,
            currentAssignments: []
        )
        ruleEngine.reconcilePreferredAssignment(for: note, in: spreads, preferredSpreadID: preferredSpreadID)
        try await noteRepository.save(note, change: EntityChange(isNew: true))
        upsertNote(note)

        if note.currentAssignments.isEmpty {
            Self.logger.debug("Note created: \(note.id, privacy: .public) '\(note.title, privacy: .public)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Note created: \(note.id, privacy: .public) '\(note.title, privacy: .public)' → \(note.period.rawValue, privacy: .public) spread")
        }

        return note
    }

    /// Deletes a note from the repository and local state.
    func deleteNote(_ note: DataModel.Note) async throws {
        try await noteRepository.delete(note)
        removeNote(id: note.id)
    }

    /// Updates a note's title and content.
    func updateNoteTitle(_ note: DataModel.Note, newTitle: String, newContent: String) async throws {
        let change = EntityChange(isNew: false, previousAssignments: note.currentAssignments + note.migrationHistory, previousTagIDs: note.tags.map(\.id))
        note.title = newTitle
        note.content = newContent
        try await noteRepository.save(note, change: change)
        upsertNote(note)
    }

    /// Updates independently mergeable note metadata (list/tags).
    func updateNoteMetadata(_ note: DataModel.Note, list: DataModel.List?, tags: [DataModel.Tag]) async throws {
        let previousTagIDs = note.tags.map(\.id)
        let timestamp = Date.now

        if note.list?.id != list?.id {
            note.list = list
            note.listUpdatedAt = timestamp
        }
        if Set(previousTagIDs) != Set(tags.map(\.id)) {
            note.tags = tags
        }

        try await noteRepository.save(note, change: EntityChange(isNew: false, previousAssignments: note.currentAssignments + note.migrationHistory, previousTagIDs: previousTagIDs))
        upsertNote(note)
    }

    /// Updates a note's preferred date and period, reconciling its spread assignment.
    func updateNoteDateAndPeriod(_ note: DataModel.Note, newDate: Date, newPeriod: Period, preferredSpreadID: UUID? = nil) async throws {
        let change = EntityChange(isNew: false, previousAssignments: note.currentAssignments + note.migrationHistory, previousTagIDs: note.tags.map(\.id))
        note.date = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.period = newPeriod
        ruleEngine.reconcilePreferredAssignment(for: note, in: spreads, preferredSpreadID: preferredSpreadID)
        try await noteRepository.save(note, change: change)
        upsertNote(note)
    }

    // MARK: - List/Tag

    /// Creates a new List with the given name.
    func createList(name: String) async throws -> DataModel.List {
        let list = DataModel.List(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        try await listRepository.save(list)
        lists = await listRepository.getLists()
        return list
    }

    /// Creates a new Tag with the given name.
    func createTag(name: String) async throws -> DataModel.Tag {
        let tag = DataModel.Tag(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        try await tagRepository.save(tag)
        tags = await tagRepository.getTags()
        return tag
    }

    // MARK: - Mutation Primitives

    /// Inserts a new task or updates an existing one, patching only the spread-data-model
    /// keys its assignments touch (the union of its keys before and after the change).
    func upsertTask(_ task: DataModel.Task) {
        let oldKeys = taskIndex.keys(for: task.id)
        taskStore.upsert(task)
        let newKeys = ruleEngine.spreadKeys(for: task, spreads: spreads)
        taskIndex.update(entityID: task.id, keys: newKeys)
        tasks = Self.sortedByCreatedDate(taskStore.values)
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
        tasks = Self.sortedByCreatedDate(taskStore.values)
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
        notes = Self.sortedByCreatedDate(noteStore.values)
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
        notes = Self.sortedByCreatedDate(noteStore.values)
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
        events = Self.sortedByCreatedDate(eventStore.values)
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
        events = Self.sortedByCreatedDate(eventStore.values)
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
    /// so it's invariant to whether the spread object itself currently exists.
    ///
    /// The previous key is read from `keyBySpreadID` rather than re-derived from the
    /// currently-stored spread object: `DataModel.Spread` is a class, and callers mutate it
    /// in place before calling this, so by the time this runs, `spreadStore[spread.id]`
    /// would already reflect the *new* state.
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
        spreads = Self.sortedSpreads(spreadStore.values)
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
        spreads = Self.sortedSpreads(spreadStore.values)
        eventIndex.removeSpread(spread)
        dataModel[key: key] = nil
        dataVersion += 1
    }
}
